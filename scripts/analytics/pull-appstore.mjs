#!/usr/bin/env node
// グロース分析ハーネス — App Store Connect 収集 (依存ゼロ / Node 標準モジュールのみ)
//
// 3 アプリ (Gymnee / BodyLapse / nihongo) は同一 ASC チーム配下で、同じ ASC キー + vendor number で
// 全アプリのレポートを引ける。本スクリプトは各リポに同一内容でコピーされ、先頭の「対象アプリ」定数だけ
// リポ固有に差し替える (bundleId/SKU の引数化)。nihongo の pull-appstore.ts を汎用化・依存ゼロ化したもの。
//
// できること:
//   1. JWT (ES256, Node 標準 crypto で自己署名) を作り GET /v1/apps で認証疎通を確認。
//   2. Sales & Trends レポート (DAILY/SUMMARY) を vendor number で日別取得 → 対象アプリの
//      Apple Identifier で行を絞り、新規DL/再DL/更新と課金 (proceeds) を集計。
//   3. Subscription レポート (best-effort) で有効サブスク数を日別取得。
//
// 使い方:
//   node scripts/analytics/pull-appstore.mjs [days=7]
//   node scripts/analytics/pull-appstore.mjs --list-apps          # チーム配下の全アプリ (id/name/bundleId/sku) を列挙
//   node scripts/analytics/pull-appstore.mjs --days 5 --bundle-id com.example --app-id 123 --no-subscriptions
//
// 設計原則: LLM を使わない決定論スクリプト。資格情報やネットワークが無くても snapshot 全体を止めないよう、
//           失敗は例外で止めず configured:false / error フィールドに載せて best-effort 継続する。
//           標準出力は集計 JSON のみ、進捗・要約は標準エラーへ。個人情報を含めず集計値のみ。
import { readFileSync, existsSync } from 'node:fs';
import { gunzipSync } from 'node:zlib';
import { createPrivateKey, sign as cryptoSign } from 'node:crypto';
import { homedir } from 'node:os';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

// ================= 対象アプリ (このリポのコピー固有 — 他リポでここだけ差し替える) =================
const APP_LABEL = 'BodyLapse';
const DEFAULT_BUNDLE_ID = 'com.J.BodyLapse';
const DEFAULT_APP_ID = '6747956750'; // bundleId ルックアップ失敗時のフォールバック用 (通常は live ルックアップを優先)
// ============================================================================================

const ASC_AUD = 'appstoreconnect-v1';
const ASC_BASE = 'https://api.appstoreconnect.apple.com';
const DAY_MS = 24 * 60 * 60 * 1000;

// ---- 資格情報の読み込み (env → ~/.config/growth/asc.env → 各リポ secrets/.env の順で解決) ----
// 共有growth設定を先にするのは、リポsecretsのASCキーがTestFlight用ロールで売上APIを引けないため
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
function expandHome(p) {
    return p && p.startsWith('~') ? resolve(homedir(), p.slice(2)) : p;
}
function loadCreds() {
    const scriptDir = dirname(fileURLToPath(import.meta.url));
    const repoSecrets = parseEnvFile(resolve(scriptDir, '../../secrets/.env'));
    const shared = parseEnvFile(resolve(homedir(), '.config/growth/asc.env'));
    const pick = (k) => process.env[k] ?? shared[k] ?? repoSecrets[k];
    const keyId = pick('ASC_KEY_ID');
    const issuerId = pick('ASC_ISSUER_ID');
    const vendorNumber = pick('ASC_VENDOR_NUMBER');
    const keyPath = expandHome(pick('ASC_KEY_PATH') ?? `~/.appstoreconnect/private_keys/AuthKey_${keyId}.p8`);
    if (!keyId || !issuerId) {
        throw new Error('ASC_KEY_ID / ASC_ISSUER_ID 未設定 (env / secrets/.env / ~/.config/growth/asc.env のいずれかに置く)');
    }
    if (!existsSync(keyPath)) throw new Error(`ASC 秘密鍵 (.p8) が見つからない: ${keyPath}`);
    return { keyId, issuerId, vendorNumber, privateKeyPem: readFileSync(keyPath, 'utf8') };
}

// ---- JWT (ES256) を Node 標準 crypto で自己署名 (jose 等の依存を持たない) ----
function b64url(input) {
    return Buffer.from(input).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
function makeJwt(creds) {
    const header = { alg: 'ES256', kid: creds.keyId, typ: 'JWT' };
    const now = Math.floor(Date.now() / 1000);
    const payload = { iss: creds.issuerId, iat: now, exp: now + 20 * 60, aud: ASC_AUD };
    const signingInput = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;
    const key = createPrivateKey(creds.privateKeyPem);
    // ES256 は R||S の生連結 (JOSE 形式) が必要。DER ではなく ieee-p1363 を指定する。
    const sig = cryptoSign('sha256', Buffer.from(signingInput), { key, dsaEncoding: 'ieee-p1363' });
    return `${signingInput}.${b64url(sig)}`;
}

async function ascGet(jwt, path, accept) {
    return fetch(`${ASC_BASE}${path}`, {
        headers: { Authorization: `Bearer ${jwt}`, ...(accept ? { Accept: accept } : {}) },
    });
}

// ---- チーム配下の全アプリを列挙 (id/name/bundleId/sku) ----
async function listApps(jwt) {
    const q = new URLSearchParams({ 'fields[apps]': 'name,bundleId,sku', limit: '200' });
    const res = await ascGet(jwt, `/v1/apps?${q}`);
    if (!res.ok) throw new Error(`apps HTTP ${res.status}: ${(await res.text()).slice(0, 200)}`);
    const json = await res.json();
    return (json.data ?? []).map((a) => ({
        id: a.id,
        name: a.attributes?.name,
        bundleId: a.attributes?.bundleId,
        sku: a.attributes?.sku,
    }));
}

// ---- Sales Report の TSV を集計。行は Apple Identifier で対象アプリに絞る ----
// Product Type Identifier: '1'* = 新規DL, '3'* / '7'* = 更新, '*T' = 再DL (無料アプリは末尾 F)。
// nihongo pull-appstore.ts の分類ヒューリスティックをそのまま踏襲し、3 アプリで一貫させる。
function parseSalesTsv(tsv, appId) {
    const lines = tsv.split('\n').filter((l) => l.trim().length > 0);
    if (lines.length < 2) return null;
    const header = lines[0].split('\t');
    const col = (name) => header.indexOf(name);
    const iType = col('Product Type Identifier');
    const iUnits = col('Units');
    const iDate = col('Begin Date');
    const iAppId = col('Apple Identifier');
    const iProceeds = col('Developer Proceeds');
    const iProceedsCcy = col('Currency of Proceeds');
    if (iType < 0 || iUnits < 0 || iDate < 0) return null;

    let firstDownloads = 0, redownloads = 0, updates = 0, iapUnits = 0;
    const proceedsByCurrency = {};
    for (const line of lines.slice(1)) {
        const cols = line.split('\t');
        // Apple Identifier で対象アプリに絞る (vendor レポートは全アプリ混在)。
        if (appId && iAppId >= 0 && (cols[iAppId] ?? '').trim() !== String(appId)) continue;
        const type = (cols[iType] ?? '').trim();
        const units = Number(cols[iUnits] ?? '0') || 0;
        if (type.startsWith('1') || type === 'F1') firstDownloads += units;
        else if (type.startsWith('3') || type.startsWith('7')) updates += units;
        else if (type.includes('T')) redownloads += units;
        else if (type.startsWith('IA') || type.startsWith('FI')) iapUnits += units; // 課金 (IAP/サブスク)
        // proceeds (通貨別に合計。混在通貨を単純合算しないため通貨ごとに保持)。
        if (iProceeds >= 0 && iProceedsCcy >= 0) {
            const per = Number(cols[iProceeds] ?? '0') || 0;
            const ccy = (cols[iProceedsCcy] ?? '').trim();
            if (per && ccy) proceedsByCurrency[ccy] = Math.round(((proceedsByCurrency[ccy] ?? 0) + per * units) * 100) / 100;
        }
    }
    return { firstDownloads, redownloads, updates, iapUnits, proceedsByCurrency };
}

async function fetchSalesForDate(jwt, vendorNumber, reportDate) {
    const q = new URLSearchParams({
        'filter[frequency]': 'DAILY',
        'filter[reportType]': 'SALES',
        'filter[reportSubType]': 'SUMMARY',
        'filter[vendorNumber]': vendorNumber,
        'filter[reportDate]': reportDate,
        'filter[version]': '1_1',
    });
    const res = await ascGet(jwt, `/v1/salesReports?${q}`, 'application/a-gzip');
    if (res.status === 404) return { status: 404 }; // その日のレポートが未生成 (vendor 全体でゼロ or 未確定)
    // 401/403 はキーのロール不足など「全日共通で発生する systemic なエラー」。日別ループを空回しさせず伝播する。
    if (res.status === 401 || res.status === 403) {
        let detail = '';
        try { detail = ((await res.json()).errors?.[0]?.detail) ?? ''; } catch { /* ignore */ }
        return { status: res.status, systemic: true, detail };
    }
    if (!res.ok) throw new Error(`salesReports ${reportDate} HTTP ${res.status}`);
    const buf = Buffer.from(await res.arrayBuffer());
    return { status: 200, tsv: gunzipSync(buf).toString('utf8') };
}

async function fetchSubscriptionsForDate(jwt, vendorNumber, reportDate, appId) {
    const q = new URLSearchParams({
        'filter[frequency]': 'DAILY',
        'filter[reportType]': 'SUBSCRIPTION',
        'filter[reportSubType]': 'SUMMARY',
        'filter[vendorNumber]': vendorNumber,
        'filter[reportDate]': reportDate,
        'filter[version]': '1_4',
    });
    const res = await ascGet(jwt, `/v1/salesReports?${q}`, 'application/a-gzip');
    if (res.status === 404) return { status: 404 };
    if (!res.ok) return { status: res.status };
    const tsv = gunzipSync(Buffer.from(await res.arrayBuffer())).toString('utf8');
    const lines = tsv.split('\n').filter((l) => l.trim().length > 0);
    if (lines.length < 2) return { status: 200, activeSubscriptions: 0 };
    const header = lines[0].split('\t');
    const iApp = header.indexOf('App Apple ID');
    const activeCols = header
        .map((h, idx) => ({ h, idx }))
        .filter((x) => /^Active .*Subscriptions$/i.test(x.h) || x.h === 'Active Standard Price Subscriptions')
        .map((x) => x.idx);
    let active = 0;
    for (const line of lines.slice(1)) {
        const cols = line.split('\t');
        if (appId && iApp >= 0 && (cols[iApp] ?? '').trim() !== String(appId)) continue;
        for (const idx of activeCols) active += Number(cols[idx] ?? '0') || 0;
    }
    return { status: 200, activeSubscriptions: active };
}

export async function pullAppStore(opts = {}) {
    const windowDays = opts.windowDays ?? 7;
    const bundleId = opts.bundleId ?? DEFAULT_BUNDLE_ID;
    const wantSubscriptions = opts.subscriptions ?? true;

    let creds;
    try {
        creds = loadCreds();
    } catch (err) {
        return { configured: false, error: `creds: ${err.message}`, app: { label: APP_LABEL, bundleId } };
    }

    try {
        const jwt = makeJwt(creds);
        // 認証疎通 + 対象アプリの numeric id を bundleId から解決 (フィルタの正)。
        let app;
        try {
            const q = new URLSearchParams({ 'filter[bundleId]': bundleId, 'fields[apps]': 'name,bundleId,sku' });
            const res = await ascGet(jwt, `/v1/apps?${q}`);
            if (res.ok) {
                const a = (await res.json()).data?.[0];
                if (a) app = { id: a.id, name: a.attributes?.name, bundleId: a.attributes?.bundleId, sku: a.attributes?.sku };
            }
        } catch { /* best-effort: 解決に失敗してもフォールバック app id で続行 */ }

        const appId = opts.appId ?? app?.id ?? DEFAULT_APP_ID;
        const out = {
            configured: true,
            app: app ?? { label: APP_LABEL, bundleId, id: appId, note: 'bundleId ルックアップ失敗。フォールバック app id を使用' },
            appIdUsedForFilter: appId,
        };

        const vendorNumber = creds.vendorNumber;
        if (!vendorNumber) {
            out.downloads = {
                vendorNumber: '(unset)',
                byDayJst: [],
                note: 'DL 数を取るには ASC_VENDOR_NUMBER (ASC 支払いと財務レポート左上の 8 桁) を ~/.config/growth/asc.env か env に設定',
            };
            return out;
        }

        const byDay = [];
        let daysNoReport = 0, daysError = 0;
        let salesError = null;
        const proceedsByCurrency = {};
        const subsByDay = [];
        // 直近 windowDays 日を 1 日ずつ (Sales Report は日別 1 リクエスト、~1-2 日遅延)。
        for (let i = 1; i <= windowDays; i++) {
            const reportDate = new Date(Date.now() - i * DAY_MS).toISOString().slice(0, 10);
            try {
                const r = await fetchSalesForDate(jwt, vendorNumber, reportDate);
                if (r.systemic) {
                    // 全日共通の systemic エラー (キーのロール不足など)。ループを止めて理由を明示する。
                    salesError = `salesReports HTTP ${r.status}: ${r.detail || 'アクセス不可'} — ` +
                        'ASC API キーに Sales/Finance/Admin ロールが必要 (現キーは TestFlight 配布用ロールで販売レポート不可)';
                    break;
                }
                if (r.status === 404) { daysNoReport++; continue; }
                const agg = parseSalesTsv(r.tsv, appId);
                // レポートは存在するが対象アプリの行がゼロ = DL ゼロの日。明示的にゼロ行を積む。
                const day = agg ?? { firstDownloads: 0, redownloads: 0, updates: 0, iapUnits: 0, proceedsByCurrency: {} };
                byDay.push({
                    day: reportDate,
                    firstDownloads: day.firstDownloads,
                    redownloads: day.redownloads,
                    updates: day.updates,
                    iapUnits: day.iapUnits,
                });
                for (const [ccy, amt] of Object.entries(day.proceedsByCurrency)) {
                    proceedsByCurrency[ccy] = Math.round(((proceedsByCurrency[ccy] ?? 0) + amt) * 100) / 100;
                }
            } catch {
                daysError++; // 個別日の失敗は無視して継続 (レポート未確定日など)。
            }
            if (wantSubscriptions) {
                try {
                    const s = await fetchSubscriptionsForDate(jwt, vendorNumber, reportDate, appId);
                    if (s.status === 200) subsByDay.push({ day: reportDate, activeSubscriptions: s.activeSubscriptions });
                } catch { /* サブスク未対応アプリ等は無視 */ }
            }
        }
        byDay.sort((a, b) => a.day.localeCompare(b.day));
        subsByDay.sort((a, b) => a.day.localeCompare(b.day));

        const totals = byDay.reduce(
            (acc, d) => ({
                firstDownloads: acc.firstDownloads + d.firstDownloads,
                redownloads: acc.redownloads + d.redownloads,
                updates: acc.updates + d.updates,
                iapUnits: acc.iapUnits + d.iapUnits,
            }),
            { firstDownloads: 0, redownloads: 0, updates: 0, iapUnits: 0 },
        );
        out.downloads = {
            vendorNumber,
            appId,
            windowDays,
            byDayJst: byDay,
            totals,
            proceedsByCurrency,
            meta: { daysWithReport: byDay.length, daysNoReport, daysError },
            ...(salesError ? { error: salesError } : {}),
        };
        if (wantSubscriptions) {
            out.subscriptions = subsByDay.length
                ? { byDayJst: subsByDay, latest: subsByDay[subsByDay.length - 1]?.activeSubscriptions ?? 0 }
                : { available: false, note: 'Subscription レポートなし (サブスク未提供 or 期間内にデータ無し)' };
        }
        return out;
    } catch (err) {
        return { configured: false, error: err.message, app: { label: APP_LABEL, bundleId } };
    }
}

// ---- CLI ----
function parseArgs(argv) {
    const args = { windowDays: 7, subscriptions: true };
    for (let i = 0; i < argv.length; i++) {
        const a = argv[i];
        if (a === '--list-apps') args.listApps = true;
        else if (a === '--no-subscriptions') args.subscriptions = false;
        else if (a === '--days') args.windowDays = Number(argv[++i]) || args.windowDays;
        else if (a === '--bundle-id') args.bundleId = argv[++i];
        else if (a === '--app-id') args.appId = argv[++i];
        else if (/^\d+$/.test(a)) args.windowDays = Number(a);
    }
    return args;
}

async function main() {
    const args = parseArgs(process.argv.slice(2));
    if (args.listApps) {
        const creds = loadCreds();
        const apps = await listApps(makeJwt(creds));
        process.stderr.write(`ASC チーム配下 ${apps.length} アプリ:\n`);
        for (const a of apps) process.stderr.write(`  ${a.id}  ${a.bundleId}  sku=${a.sku}  ${a.name}\n`);
        process.stdout.write(JSON.stringify(apps, null, 2) + '\n');
        return;
    }
    const data = await pullAppStore(args);
    const d = data.downloads;
    process.stderr.write(
        [
            `[${APP_LABEL}] App Store 収集 (直近 ${args.windowDays} 日)`,
            data.configured
                ? `  app: ${data.app?.name ?? data.app?.label} (id ${data.appIdUsedForFilter ?? '?'} / ${data.app?.bundleId})`
                : `  skip: ${data.error}`,
            d && d.error
                ? `  DL: 取得不可 — ${d.error}`
                : d && d.totals
                ? `  DL 合計: 新規 ${d.totals.firstDownloads} / 再DL ${d.totals.redownloads} / 更新 ${d.totals.updates} / 課金unit ${d.totals.iapUnits}  (レポート有 ${d.meta.daysWithReport}日 / 無 ${d.meta.daysNoReport}日)`
                : `  DL: ${d?.note ?? 'n/a'}`,
            data.subscriptions
                ? `  サブスク: ${data.subscriptions.available === false ? 'なし' : '有効 ' + data.subscriptions.latest}`
                : '',
        ].filter(Boolean).join('\n') + '\n',
    );
    process.stdout.write(JSON.stringify(data, null, 2) + '\n');
}

if (import.meta.url === `file://${process.argv[1]}`) {
    main().catch((err) => {
        console.error(err);
        process.exit(1);
    });
}
