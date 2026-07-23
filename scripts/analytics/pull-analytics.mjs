#!/usr/bin/env node
// グロース分析ハーネス — App Store Connect App Analytics 収集 (依存ゼロ / Node 標準モジュールのみ)
//
// BodyLapse は完全オフライン設計 (UserDefaults + ファイルシステム、サーバ側 DB 無し)。
// そのため「DL 以降の行動ファネル」の唯一の代替源が ASC の App Analytics Reports API。
// 本スクリプトは Analytics Reports API (analyticsReportRequests → reports → instances → segments)
// を **現行の共有 ASC キー (売上ロール) で実際に叩いて疎通を確認**し、取れる指標
// (セッション / アクティブデバイス / インストール) だけを集計する調査込みの収集スクリプト。
//
// 重要な性質 (Apple の設計):
//   - Analytics Reports は **非同期・レポートリクエスト方式**。app ごとに一度 ONGOING の
//     analyticsReportRequest を作ると、そこから日次レポートが生成され始める。
//   - **初回リクエスト直後はまだレポート実体 (instances/segments) が無い**。生成完了まで
//     最大 24〜48h かかる。→ 初回は configured:true / pending:true で「生成待ち」を返し、
//     snapshot を止めない。次回以降の実行で instances が現れたら集計に移る。
//   - キーのロールが Analytics を許可していない場合は 401/403 → configured:false + 理由。
//
// 設計原則 (pull-appstore.mjs / pull-supabase.mjs を踏襲):
//   - LLM を使わない決定論スクリプト。資格情報やネットワークが無くても snapshot 全体を
//     止めないよう、失敗は例外で止めず configured:false / pending / note に載せて best-effort。
//   - 標準出力は集計 JSON のみ、進捗・要約は標準エラーへ。個人情報を含めず集計値のみ。
//
// 実測 (2026-07, BodyLapse / 共有売上ロールキー):
//   - GET /v1/apps/{id}/analyticsReportRequests → **200** (読み取り疎通 OK)。ただし ONGOING リクエストは未作成 (0 件)。
//   - POST /v1/analyticsReportRequests (作成) → **403** "The API key in use does not allow this request"。
//     → 現行キー(売上ロール)では App Analytics のブートストラップ(ONGOING 作成)が不可。Admin/App Manager ロールが要る。
//   - 既定では作成を試みず configured:false + setupRequired で理由を返す (snapshot を止めない)。
//
// 使い方:
//   node scripts/analytics/pull-analytics.mjs [days=30]           # 読み取りのみ (既定: 作成しない)
//   node scripts/analytics/pull-analytics.mjs --create            # ONGOING リクエスト作成を試行 (Admin ロールキーが必要)
import { readFileSync, existsSync } from 'node:fs';
import { gunzipSync } from 'node:zlib';
import { createPrivateKey, sign as cryptoSign } from 'node:crypto';
import { homedir } from 'node:os';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

// ================= 対象アプリ (このリポのコピー固有) =================
const APP_LABEL = 'BodyLapse';
const DEFAULT_BUNDLE_ID = 'com.J.BodyLapse';
const DEFAULT_APP_ID = '6747956750';
// ====================================================================

const ASC_AUD = 'appstoreconnect-v1';
const ASC_BASE = 'https://api.appstoreconnect.apple.com';
const DAY_MS = 24 * 60 * 60 * 1000;

// ---- 資格情報の読み込み (pull-appstore.mjs と同型: env → ~/.config/growth/asc.env → secrets/.env) ----
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
    const keyPath = expandHome(pick('ASC_KEY_PATH') ?? `~/.appstoreconnect/private_keys/AuthKey_${keyId}.p8`);
    if (!keyId || !issuerId) {
        throw new Error('ASC_KEY_ID / ASC_ISSUER_ID 未設定 (env / secrets/.env / ~/.config/growth/asc.env のいずれかに置く)');
    }
    if (!existsSync(keyPath)) throw new Error(`ASC 秘密鍵 (.p8) が見つからない: ${keyPath}`);
    return { keyId, issuerId, privateKeyPem: readFileSync(keyPath, 'utf8') };
}

// ---- JWT (ES256) を Node 標準 crypto で自己署名 ----
function b64url(input) {
    return Buffer.from(input).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
function makeJwt(creds) {
    const header = { alg: 'ES256', kid: creds.keyId, typ: 'JWT' };
    const now = Math.floor(Date.now() / 1000);
    const payload = { iss: creds.issuerId, iat: now, exp: now + 20 * 60, aud: ASC_AUD };
    const signingInput = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;
    const key = createPrivateKey(creds.privateKeyPem);
    const sig = cryptoSign('sha256', Buffer.from(signingInput), { key, dsaEncoding: 'ieee-p1363' });
    return `${signingInput}.${b64url(sig)}`;
}

async function ascGet(jwt, path, accept) {
    return fetch(path.startsWith('http') ? path : `${ASC_BASE}${path}`, {
        headers: { Authorization: `Bearer ${jwt}`, ...(accept ? { Accept: accept } : {}) },
    });
}
async function ascPost(jwt, path, body) {
    return fetch(`${ASC_BASE}${path}`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${jwt}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
    });
}

// ---- 対象アプリの numeric id を bundleId から解決 ----
async function resolveAppId(jwt, bundleId) {
    try {
        const q = new URLSearchParams({ 'filter[bundleId]': bundleId, 'fields[apps]': 'name,bundleId,sku' });
        const res = await ascGet(jwt, `/v1/apps?${q}`);
        if (res.ok) {
            const a = (await res.json()).data?.[0];
            if (a) return { id: a.id, name: a.attributes?.name, bundleId: a.attributes?.bundleId, sku: a.attributes?.sku };
        }
    } catch { /* best-effort */ }
    return { id: DEFAULT_APP_ID, bundleId, note: 'bundleId ルックアップ失敗。フォールバック app id を使用' };
}

// ---- エラー詳細の抽出 ----
async function errDetail(res) {
    try {
        const j = await res.json();
        const e = j.errors?.[0];
        return e ? `${e.title ?? ''}: ${e.detail ?? ''}`.trim() : JSON.stringify(j).slice(0, 200);
    } catch {
        try { return (await res.text()).slice(0, 200); } catch { return ''; }
    }
}

// ---- ONGOING レポートリクエストの取得 (無ければ null) ----
// 返り値: { status, requests?: [{id, accessType, stoppedDueToInactivity}], detail? }
async function listReportRequests(jwt, appId) {
    const q = new URLSearchParams({
        'filter[accessType]': 'ONGOING',
        'fields[analyticsReportRequests]': 'accessType,stoppedDueToInactivity',
        limit: '50',
    });
    const res = await ascGet(jwt, `/v1/apps/${appId}/analyticsReportRequests?${q}`);
    if (res.status === 401 || res.status === 403) {
        return { status: res.status, systemic: true, detail: await errDetail(res) };
    }
    if (!res.ok) return { status: res.status, detail: await errDetail(res) };
    const json = await res.json();
    return {
        status: 200,
        requests: (json.data ?? []).map((r) => ({
            id: r.id,
            accessType: r.attributes?.accessType,
            stoppedDueToInactivity: r.attributes?.stoppedDueToInactivity,
        })),
    };
}

// ---- ONGOING レポートリクエストを新規作成 (初回セットアップ。以後データ生成が始まる) ----
async function createReportRequest(jwt, appId) {
    const body = {
        data: {
            type: 'analyticsReportRequests',
            attributes: { accessType: 'ONGOING' },
            relationships: { app: { data: { type: 'apps', id: String(appId) } } },
        },
    };
    const res = await ascPost(jwt, '/v1/analyticsReportRequests', body);
    if (res.status === 201) {
        const id = (await res.json()).data?.id;
        return { ok: true, id };
    }
    // 409 = 既に ONGOING リクエストが存在 (競合)。呼び出し側で再取得させる。
    if (res.status === 409) return { ok: false, conflict: true, detail: await errDetail(res) };
    return { ok: false, status: res.status, detail: await errDetail(res) };
}

// ---- レポートリクエスト配下の利用可能レポート一覧 (name/category) ----
async function listReports(jwt, requestId) {
    const reports = [];
    let url = `/v1/analyticsReportRequests/${requestId}/reports?${new URLSearchParams({
        'fields[analyticsReports]': 'name,category',
        limit: '200',
    })}`;
    // ページネーション (links.next)。
    for (let guard = 0; url && guard < 10; guard++) {
        const res = await ascGet(jwt, url);
        if (!res.ok) return { status: res.status, detail: await errDetail(res), reports };
        const json = await res.json();
        for (const r of json.data ?? []) {
            reports.push({ id: r.id, name: r.attributes?.name, category: r.attributes?.category });
        }
        url = json.links?.next ?? null;
    }
    return { status: 200, reports };
}

// ---- 特定レポートの DAILY instances を新しい順に取得 ----
async function listInstances(jwt, reportId) {
    const q = new URLSearchParams({ 'filter[granularity]': 'DAILY', limit: '200' });
    const res = await ascGet(jwt, `/v1/analyticsReports/${reportId}/instances?${q}`);
    if (!res.ok) return { status: res.status, detail: await errDetail(res), instances: [] };
    const json = await res.json();
    const instances = (json.data ?? [])
        .map((i) => ({ id: i.id, processingDate: i.attributes?.processingDate, granularity: i.attributes?.granularity }))
        .filter((i) => i.processingDate)
        .sort((a, b) => b.processingDate.localeCompare(a.processingDate));
    return { status: 200, instances };
}

// ---- instance の segments を取得しダウンロード → gzip 解凍 → CSV 行配列 ----
async function fetchInstanceRows(jwt, instanceId) {
    const res = await ascGet(jwt, `/v1/analyticsReportInstances/${instanceId}/segments?${new URLSearchParams({ limit: '50' })}`);
    if (!res.ok) return { status: res.status, detail: await errDetail(res), rows: [] };
    const json = await res.json();
    const rows = [];
    let header = null;
    for (const seg of json.data ?? []) {
        const dlUrl = seg.attributes?.url;
        if (!dlUrl) continue;
        // segment の url は署名付き S3。Authorization ヘッダは付けない (付けると署名衝突)。
        const dl = await fetch(dlUrl);
        if (!dl.ok) continue;
        const buf = Buffer.from(await dl.arrayBuffer());
        let text;
        try { text = gunzipSync(buf).toString('utf8'); } catch { text = buf.toString('utf8'); }
        // Apple の Analytics レポートは TSV。
        const lines = text.split('\n').filter((l) => l.trim().length > 0);
        if (lines.length < 2) continue;
        if (!header) header = lines[0].split('\t');
        for (const line of lines.slice(1)) rows.push(line.split('\t'));
    }
    return { status: 200, header, rows };
}

// ---- TSV 行から数値カラムを合計 (カラム名は candidates のいずれか) ----
function sumColumn(header, rows, candidates) {
    if (!header) return null;
    const idx = header.findIndex((h) => candidates.some((c) => h.trim().toLowerCase() === c.toLowerCase()));
    if (idx < 0) return null;
    let total = 0;
    for (const cols of rows) total += Number((cols[idx] ?? '0').replace(/,/g, '')) || 0;
    return total;
}

// 集計したいレポートの名前パターン (Apple の標準レポート名は将来変わりうるため regex で緩く一致)。
const WANTED = [
    { key: 'sessions', re: /session/i, valueCols: ['Sessions', 'Total Sessions'] },
    { key: 'activeDevices', re: /active devices|active last/i, valueCols: ['Active Devices', 'Unique Devices'] },
    { key: 'installs', re: /install/i, valueCols: ['Installations', 'Total Downloads', 'Installs'] },
];

export async function pullAnalytics(opts = {}) {
    const windowDays = opts.windowDays ?? 30;
    const bundleId = opts.bundleId ?? DEFAULT_BUNDLE_ID;
    // 既定は作成を試みない (weekly snapshot が毎回 POST 403 を叩かないように)。
    // 実測 (2026-07): 現行の共有キー=売上ロールは GET (読み取り) 200 だが POST (作成) 403。
    // ONGOING リクエストの作成には Admin / App Manager ロールが要る。--create で明示的に試行できる。
    const autoCreate = opts.autoCreate ?? false;

    let creds;
    try {
        creds = loadCreds();
    } catch (err) {
        return { configured: false, source: 'asc-app-analytics', error: `creds: ${err.message}`, app: { label: APP_LABEL, bundleId } };
    }

    try {
        const jwt = makeJwt(creds);
        const app = await resolveAppId(jwt, bundleId);
        const appId = opts.appId ?? app.id;
        const base = { source: 'asc-app-analytics', app: { label: APP_LABEL, ...app } };

        // 1. ONGOING レポートリクエストの有無を確認 (= このキーで Analytics API が叩けるかの疎通判定)。
        let lr = await listReportRequests(jwt, appId);
        if (lr.systemic) {
            // 401/403 = キーのロールが Analytics を許可していない。ここが可否判定の核心。
            return {
                ...base,
                configured: false,
                accessible: false,
                error: `Analytics Reports API アクセス不可 (HTTP ${lr.status}): ${lr.detail || 'ロール不足'} — ` +
                    'ASC API キーに Admin もしくは App Manager ロールが必要 (現キーで不可なら App Analytics は使えない)',
            };
        }
        if (lr.status !== 200) {
            return { ...base, configured: false, accessible: false, error: `analyticsReportRequests HTTP ${lr.status}: ${lr.detail}` };
        }

        // 疎通 OK (API はこのキーで叩けた)。
        let requests = lr.requests;

        // 2. ONGOING リクエストが無ければ (初回) 作成し、生成待ちを返す。
        if (requests.length === 0) {
            if (!autoCreate) {
                return {
                    ...base, configured: false, accessible: true, setupRequired: true,
                    note: 'Analytics Reports API は現行キーで読み取り可 (GET 200) だが、行動データの前提である ' +
                        'ONGOING レポートリクエストが未作成。作成 (POST) は現行の売上ロールキーでは 403 のため、' +
                        'Admin / App Manager ロールの ASC キーで一度 `--create` するか ASC UI で有効化する必要がある。' +
                        '有効化後は以後この同じキーで instances を読める見込み (読み取りは疎通済み)。',
                };
            }
            const created = await createReportRequest(jwt, appId);
            if (created.ok) {
                return {
                    ...base, configured: true, accessible: true, pending: true, reportRequestId: created.id,
                    note: 'ONGOING レポートリクエストを新規作成。レポート実体の生成に最大 24〜48h。次回以降の snapshot で instances が現れたら集計に移る',
                };
            }
            if (created.conflict) {
                // 競合 = 既に存在。再取得して続行。
                lr = await listReportRequests(jwt, appId);
                requests = lr.requests ?? [];
            } else {
                return {
                    ...base, configured: false, accessible: true,
                    error: `レポートリクエスト作成不可 (HTTP ${created.status}): ${created.detail} — ` +
                        '疎通はできるが作成権限が無い可能性 (Admin/App Manager ロールで再試行)',
                };
            }
        }

        if (requests.length === 0) {
            return { ...base, configured: true, accessible: true, pending: true, note: 'ONGOING レポートリクエストが確認できない (作成直後の反映待ちの可能性)' };
        }

        const requestId = requests[0].id;

        // 3. 利用可能レポート一覧を取得。空 = まだ生成中 (pending)。
        const rep = await listReports(jwt, requestId);
        const catalog = (rep.reports ?? []).map((r) => ({ name: r.name, category: r.category }));
        if (!rep.reports || rep.reports.length === 0) {
            return {
                ...base, configured: true, accessible: true, pending: true, reportRequestId: requestId,
                stoppedDueToInactivity: requests[0].stoppedDueToInactivity ?? false,
                note: rep.status === 200
                    ? 'レポートリクエストは存在するがレポート実体がまだ 0 件 (生成中。初回は最大 24〜48h)。'
                    : `reports 取得 HTTP ${rep.status}: ${rep.detail}`,
                catalog,
            };
        }

        // 4. 欲しい指標のレポートを名前パターンで拾い、最新 DAILY instance の segments を集計。
        const since = new Date(Date.now() - windowDays * DAY_MS).toISOString().slice(0, 10);
        const metrics = {};
        const fetched = [];
        for (const want of WANTED) {
            const report = rep.reports.find((r) => want.re.test(r.name ?? ''));
            if (!report) continue;
            const inst = await listInstances(jwt, report.id);
            const recent = (inst.instances ?? []).filter((i) => i.processingDate >= since);
            if (recent.length === 0) continue;
            let total = 0, days = 0, latestDay = null, gotValueCol = false;
            for (const i of recent) {
                const data = await fetchInstanceRows(jwt, i.id);
                const v = sumColumn(data.header, data.rows, want.valueCols);
                if (v != null) { total += v; days++; gotValueCol = true; if (!latestDay || i.processingDate > latestDay) latestDay = i.processingDate; }
            }
            if (gotValueCol) {
                metrics[want.key] = { total, daysWithData: days, latestProcessingDate: latestDay };
                fetched.push(report.name);
            }
        }

        if (Object.keys(metrics).length === 0) {
            return {
                ...base, configured: true, accessible: true, pending: true, reportRequestId: requestId,
                note: '利用可能レポートはあるが、指定窓内の DAILY instance / 目的カラムがまだ無い (生成待ち or カラム名要調整)。catalog を参照',
                catalog,
            };
        }

        return {
            ...base, configured: true, accessible: true, pending: false, reportRequestId: requestId, windowDays,
            metrics, reportsFetched: fetched, catalog,
        };
    } catch (err) {
        return { configured: false, source: 'asc-app-analytics', error: err.message, app: { label: APP_LABEL, bundleId } };
    }
}

// ---- CLI ----
function parseArgs(argv) {
    const args = { windowDays: 30, autoCreate: false };
    for (let i = 0; i < argv.length; i++) {
        const a = argv[i];
        if (a === '--days') args.windowDays = Number(argv[++i]) || args.windowDays;
        else if (a === '--create') args.autoCreate = true; // ONGOING リクエスト作成を試行 (Admin ロールキーが必要)
        else if (a === '--no-create') args.autoCreate = false;
        else if (a === '--bundle-id') args.bundleId = argv[++i];
        else if (a === '--app-id') args.appId = argv[++i];
        else if (/^\d+$/.test(a)) args.windowDays = Number(a);
    }
    return args;
}

async function main() {
    const args = parseArgs(process.argv.slice(2));
    const data = await pullAnalytics(args);
    const lines = [`[${APP_LABEL}] App Analytics 収集 (直近 ${args.windowDays} 日)`];
    if (!data.configured) {
        lines.push(`  skip: ${data.error ?? data.note}`);
    } else if (data.pending) {
        lines.push(`  疎通 OK / 生成待ち: ${data.note}`);
        if (data.catalog?.length) lines.push(`  利用可能レポート ${data.catalog.length} 種: ${data.catalog.map((c) => c.name).slice(0, 8).join(', ')}`);
    } else {
        for (const [k, v] of Object.entries(data.metrics ?? {})) {
            lines.push(`  ${k}: 合計 ${v.total} (${v.daysWithData}日ぶん, 最新 ${v.latestProcessingDate})`);
        }
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
