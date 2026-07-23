#!/usr/bin/env node
// グロース分析ハーネス — AdMob 広告収益 収集 (依存ゼロ / Node 標準モジュールのみ)
//
// BodyLapse は完全オフラインで、無料ユーザーの主収益が AdMob 広告 (Premium は広告非表示)。
// 本スクリプトは AdMob API (admob.googleapis.com v1) の networkReport:generate で
// 推定収益 / 表示回数 / クリック / eCPM を **集計値だけ** 日別に取り、日付付き JSON に落とす。
//
// 認証: admob-auth.mjs が一度きり OAuth で保存した ~/.config/growth/admob.env の
//   ADMOB_REFRESH_TOKEN から access token を都度発行する (サービスアカウント非対応のため)。
//   → **OAuth 未実施なら configured:false + 「admob-auth.mjs を実行してください」で best-effort スキップ**し
//     snapshot を止めない (PSEO の未認証ゲートと同型)。
//
// 設計原則 (pull-appstore.mjs / pull-analytics.mjs を踏襲):
//   - LLM を使わない決定論スクリプト。資格情報やネットワークが無くても snapshot 全体を止めない。
//   - 標準出力は集計 JSON のみ、進捗・要約は標準エラーへ。個人情報を含めず集計値のみ。
//
// 使い方:
//   node scripts/analytics/pull-admob.mjs [days=30]
import { readFileSync, existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { resolve } from 'node:path';

const TOKEN_ENDPOINT = 'https://oauth2.googleapis.com/token';
const ADMOB_BASE = 'https://admob.googleapis.com/v1';
const ADMOB_ENV = resolve(homedir(), '.config/growth/admob.env');
const DAY_MS = 24 * 60 * 60 * 1000;

function parseEnvFile(path) {
    const kv = {};
    if (!existsSync(path)) return kv;
    for (const line of readFileSync(path, 'utf8').split('\n')) {
        if (line.trim().startsWith('#')) continue;
        const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/);
        if (m) kv[m[1]] = m[2].replace(/^["']|["']$/g, '');
    }
    return kv;
}

// ---- 資格情報の解決 (env 優先 → ~/.config/growth/admob.env) ----
function loadCreds() {
    const file = parseEnvFile(ADMOB_ENV);
    const pick = (k) => process.env[k] ?? file[k];
    return {
        clientId: pick('GOOGLE_OAUTH_CLIENT_ID'),
        clientSecret: pick('GOOGLE_OAUTH_CLIENT_SECRET'),
        refreshToken: pick('ADMOB_REFRESH_TOKEN'),
        publisherId: pick('ADMOB_PUBLISHER_ID'),
    };
}

async function accessTokenFromRefresh({ clientId, clientSecret, refreshToken }) {
    const body = new URLSearchParams({
        client_id: clientId, client_secret: clientSecret,
        refresh_token: refreshToken, grant_type: 'refresh_token',
    });
    const res = await fetch(TOKEN_ENDPOINT, {
        method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body,
    });
    if (!res.ok) throw new Error(`access token 発行失敗 HTTP ${res.status}: ${(await res.text()).slice(0, 200)}`);
    return (await res.json()).access_token;
}

// ---- パブリッシャーアカウント (pub-...) を解決 ----
async function resolvePublisher(token, explicit) {
    if (explicit) return explicit;
    const res = await fetch(`${ADMOB_BASE}/accounts`, { headers: { Authorization: `Bearer ${token}` } });
    if (!res.ok) throw new Error(`accounts.list HTTP ${res.status}: ${(await res.text()).slice(0, 200)}`);
    const acct = (await res.json()).account?.[0];
    if (!acct?.publisherId) throw new Error('AdMob アカウントが見つからない (このユーザーに AdMob 発行者権限が無い可能性)');
    return acct.publisherId;
}

function ymd(date) {
    const d = new Date(date);
    return { year: d.getUTCFullYear(), month: d.getUTCMonth() + 1, day: d.getUTCDate() };
}

// ---- networkReport:generate で日別の収益/表示/クリック/eCPM を取る ----
async function fetchNetworkReport(token, publisherId, windowDays) {
    const end = new Date(Date.now() - 1 * DAY_MS);              // 昨日まで (当日は未確定)
    const start = new Date(Date.now() - windowDays * DAY_MS);
    const spec = {
        reportSpec: {
            dateRange: { startDate: ymd(start), endDate: ymd(end) },
            dimensions: ['DATE'],
            metrics: ['ESTIMATED_EARNINGS', 'IMPRESSIONS', 'CLICKS', 'AD_REQUESTS', 'MATCHED_REQUESTS'],
        },
    };
    const res = await fetch(`${ADMOB_BASE}/accounts/${publisherId}/networkReport:generate`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(spec),
    });
    if (!res.ok) throw new Error(`networkReport HTTP ${res.status}: ${(await res.text()).slice(0, 300)}`);
    // レスポンスは {header}/{row}/{footer} の JSON 配列 (streaming 風)。
    const payload = await res.json();
    const rows = Array.isArray(payload) ? payload : [payload];
    let currency = null;
    const byDay = [];
    let earningsMicros = 0, impressions = 0, clicks = 0, adRequests = 0, matchedRequests = 0;
    for (const item of rows) {
        if (item.header?.localizationSettings?.currencyCode) currency = item.header.localizationSettings.currencyCode;
        const r = item.row;
        if (!r) continue;
        const dims = r.dimensionValues ?? {};
        const mets = r.metricValues ?? {};
        const day = dims.DATE?.value; // "YYYYMMDD"
        const eMicros = Number(mets.ESTIMATED_EARNINGS?.microsValue ?? 0) || 0;
        const imp = Number(mets.IMPRESSIONS?.integerValue ?? 0) || 0;
        const clk = Number(mets.CLICKS?.integerValue ?? 0) || 0;
        const req = Number(mets.AD_REQUESTS?.integerValue ?? 0) || 0;
        const matched = Number(mets.MATCHED_REQUESTS?.integerValue ?? 0) || 0;
        earningsMicros += eMicros; impressions += imp; clicks += clk; adRequests += req; matchedRequests += matched;
        byDay.push({
            day: day ? `${day.slice(0, 4)}-${day.slice(4, 6)}-${day.slice(6, 8)}` : null,
            estimatedEarnings: Math.round((eMicros / 1e6) * 100) / 100,
            impressions: imp, clicks: clk,
        });
    }
    byDay.sort((a, b) => (a.day ?? '').localeCompare(b.day ?? ''));
    const earnings = Math.round((earningsMicros / 1e6) * 100) / 100;
    const ecpm = impressions > 0 ? Math.round((earnings / impressions) * 1000 * 100) / 100 : 0;
    const matchRate = adRequests > 0 ? Math.round((matchedRequests / adRequests) * 1000) / 10 : null;
    return {
        currency: currency ?? 'unknown', windowDays, byDayJst: byDay,
        totals: { estimatedEarnings: earnings, impressions, clicks, adRequests, matchedRequests, ecpm, matchRatePct: matchRate },
    };
}

export async function pullAdmob(opts = {}) {
    const windowDays = opts.windowDays ?? 30;
    const creds = loadCreds();

    // 未認証ゲート: refresh token が無ければ best-effort スキップ (snapshot を止めない)。
    if (!creds.refreshToken || !creds.clientId || !creds.clientSecret) {
        return {
            configured: false,
            source: 'admob',
            note: 'AdMob 未認証。`node scripts/analytics/admob-auth.mjs` を一度実行して OAuth 同意すると、' +
                `refresh token が ${ADMOB_ENV} に保存され、以後この収集が有効になります (Premium は広告非表示なので広告は無料ユーザーのみ)。`,
        };
    }

    try {
        const token = await accessTokenFromRefresh(creds);
        const publisherId = await resolvePublisher(token, creds.publisherId);
        const report = await fetchNetworkReport(token, publisherId, windowDays);
        return { configured: true, source: 'admob', publisherId, ...report };
    } catch (err) {
        return { configured: false, source: 'admob', error: err.message };
    }
}

// ---- CLI ----
function parseArgs(argv) {
    const args = { windowDays: 30 };
    for (let i = 0; i < argv.length; i++) {
        const a = argv[i];
        if (a === '--days') args.windowDays = Number(argv[++i]) || args.windowDays;
        else if (/^\d+$/.test(a)) args.windowDays = Number(a);
    }
    return args;
}

async function main() {
    const args = parseArgs(process.argv.slice(2));
    const data = await pullAdmob(args);
    const lines = [`[BodyLapse] AdMob 収集 (直近 ${args.windowDays} 日)`];
    if (!data.configured) {
        lines.push(`  skip: ${data.error ?? data.note}`);
    } else {
        const t = data.totals ?? {};
        lines.push(`  推定収益: ${t.estimatedEarnings} ${data.currency} / 表示 ${t.impressions} / クリック ${t.clicks} / eCPM ${t.ecpm}`);
    }
    process.stderr.write(lines.join('\n') + '\n');
    process.stdout.write(JSON.stringify(data, null, 2) + '\n');
}

if (import.meta.url === `file://${process.argv[1]}`) {
    main().catch((err) => {
        console.error(err);
        process.exit(1);
    });
}
