#!/usr/bin/env node
// グロース分析ハーネス — AdMob OAuth 一度きり認証 (依存ゼロ / Node 標準モジュールのみ)
//
// BodyLapse の無料ユーザー主収益は AdMob 広告。AdMob API (admob.googleapis.com v1) は
// **サービスアカウント非対応** で、AdMob アカウントを所有する Google アカウント本人の
// OAuth2 同意が必須 (スコープ https://www.googleapis.com/auth/admob.readonly)。
// PSEO の auth-oauth.sh と同型の「一度きり OAuth」をこのスクリプトで行い、**リフレッシュ
// トークンを ~/.config/growth/admob.env に保存**する。以後 pull-admob.mjs はこの refresh
// token から access token を都度発行して収集する (再ログイン不要。headless 週次も可)。
//
// 前提: デスクトップ型 OAuth クライアント JSON を用意し、下記いずれかに置く (git 外):
//   ~/.config/growth/admob-oauth-client.json   (推奨)
//   または --client <path> で明示
//   Google Cloud Console → API とサービス → 認証情報 → OAuth クライアント ID → アプリの種類「デスクトップ」
//   で作成し、ダウンロードした JSON をそのまま置く ({ "installed": { "client_id", "client_secret", ... } })。
//   AdMob API (admob.googleapis.com) をそのプロジェクトで「有効」にしておくこと。
//
// 認証フロー: ループバック (127.0.0.1) 方式。ローカルに一時 HTTP サーバを立て、ブラウザで
//   Google の同意画面 → 認可コードをローカルで受け取り → refresh_token に交換して保存。
//   ('urn:...:oob' コピペ方式は Google が廃止済みのため使わない)。
//
// 使い方:
//   node scripts/analytics/admob-auth.mjs
//   node scripts/analytics/admob-auth.mjs --client ~/Downloads/client_secret_xxx.json
import { readFileSync, writeFileSync, existsSync, mkdirSync, chmodSync } from 'node:fs';
import { createServer } from 'node:http';
import { homedir } from 'node:os';
import { resolve, dirname } from 'node:path';
import { spawn } from 'node:child_process';

const SCOPE = 'https://www.googleapis.com/auth/admob.readonly';
const AUTH_ENDPOINT = 'https://accounts.google.com/o/oauth2/v2/auth';
const TOKEN_ENDPOINT = 'https://oauth2.googleapis.com/token';
const CONFIG_DIR = resolve(homedir(), '.config/growth');
const DEFAULT_CLIENT = resolve(CONFIG_DIR, 'admob-oauth-client.json');
const OUT_ENV = resolve(CONFIG_DIR, 'admob.env');

function loadClient(path) {
    if (!existsSync(path)) {
        throw new Error(
            `OAuth クライアント JSON が見つからない: ${path}\n` +
            '  Google Cloud Console でデスクトップ型 OAuth クライアントを作成し、JSON をこのパスに置いてください。\n' +
            '  (--client <path> でも指定可)。対象プロジェクトで AdMob API を有効化しておくこと。',
        );
    }
    const raw = JSON.parse(readFileSync(path, 'utf8'));
    const c = raw.installed ?? raw.web ?? raw;
    if (!c.client_id || !c.client_secret) throw new Error(`client_id / client_secret が JSON に無い: ${path}`);
    return { clientId: c.client_id, clientSecret: c.client_secret };
}

function openBrowser(url) {
    // macOS は open。失敗しても URL を表示するので致命ではない。
    try { spawn('open', [url], { stdio: 'ignore', detached: true }).unref(); } catch { /* ignore */ }
}

// ---- ループバックで認可コードを受け取る一時サーバ ----
// listen 済みポートを確定してから認可 URL (redirect_uri) を作る必要があるため、
// サーバ起動 (port 確定) と 認可コード受信 (codePromise) を分けて返す。
function startLoopbackServer() {
    return new Promise((resolvePromise, reject) => {
        let onCode;
        const codePromise = new Promise((res, rej) => { onCode = { res, rej }; });
        const server = createServer((req, res) => {
            const u = new URL(req.url, 'http://127.0.0.1');
            if (u.pathname !== '/') { res.writeHead(404); res.end(); return; }
            const code = u.searchParams.get('code');
            const state = u.searchParams.get('state');
            const error = u.searchParams.get('error');
            res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
            if (error) {
                res.end(`<h2>認証エラー: ${error}</h2>`);
                server.close(); onCode.rej(new Error(`OAuth エラー: ${error}`)); return;
            }
            res.end('<h2>認証完了</h2><p>このタブを閉じてターミナルに戻ってください。</p>');
            server.close();
            onCode.res({ code, state });
        });
        server.on('error', reject);
        server.listen(0, '127.0.0.1', () => {
            const port = server.address().port;
            resolvePromise({ port, codePromise, redirectUri: `http://127.0.0.1:${port}` });
        });
    });
}

async function exchangeCode({ clientId, clientSecret, code, redirectUri }) {
    const body = new URLSearchParams({
        code, client_id: clientId, client_secret: clientSecret,
        redirect_uri: redirectUri, grant_type: 'authorization_code',
    });
    const res = await fetch(TOKEN_ENDPOINT, {
        method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body,
    });
    if (!res.ok) throw new Error(`トークン交換失敗 HTTP ${res.status}: ${(await res.text()).slice(0, 300)}`);
    return res.json();
}

function saveEnv({ clientId, clientSecret, refreshToken }) {
    mkdirSync(CONFIG_DIR, { recursive: true });
    const content =
        '# グロース分析ハーネス — AdMob OAuth 資格情報 (git 外・BodyLapse 用)\n' +
        `# 生成: ${new Date().toISOString()} — admob-auth.mjs による一度きり認証\n` +
        '# pull-admob.mjs がこの refresh token から access token を都度発行して収集する。\n' +
        `GOOGLE_OAUTH_CLIENT_ID=${clientId}\n` +
        `GOOGLE_OAUTH_CLIENT_SECRET=${clientSecret}\n` +
        `ADMOB_REFRESH_TOKEN=${refreshToken}\n` +
        '# ADMOB_PUBLISHER_ID=pub-XXXXXXXXXXXXXXXX   # 任意。未設定なら accounts.list で自動解決\n';
    writeFileSync(OUT_ENV, content);
    try { chmodSync(OUT_ENV, 0o600); } catch { /* best-effort */ }
}

async function main() {
    const argv = process.argv.slice(2);
    let clientPath = DEFAULT_CLIENT;
    for (let i = 0; i < argv.length; i++) {
        if (argv[i] === '--client') clientPath = resolve(expandHome(argv[++i]));
    }
    const { clientId, clientSecret } = loadClient(clientPath);

    const { port, codePromise, redirectUri } = await startLoopbackServer();
    const state = Math.random().toString(36).slice(2) + Date.now().toString(36);
    const authUrl = `${AUTH_ENDPOINT}?${new URLSearchParams({
        client_id: clientId,
        redirect_uri: redirectUri,
        response_type: 'code',
        scope: SCOPE,
        access_type: 'offline',   // refresh_token を得るために必須
        prompt: 'consent',        // 毎回 refresh_token を確実に返させる
        state,
    })}`;

    process.stderr.write(
        `▶ AdMob OAuth を開始します (ポート ${port} で待受)。\n` +
        '  ブラウザが開きます。AdMob を所有する Google アカウント (例: kojokamo120@gmail.com) を選び、\n' +
        '  「未確認アプリ」の警告が出たら 詳細 → 続行 で突破してください。\n' +
        '  ブラウザが自動で開かない場合は次の URL を手動で開いてください:\n\n' +
        `  ${authUrl}\n\n`,
    );
    openBrowser(authUrl);

    const { code, state: gotState } = await codePromise;
    if (gotState !== state) throw new Error('state 不一致 (CSRF 防止のため中断)');

    const tok = await exchangeCode({ clientId, clientSecret, code, redirectUri });
    if (!tok.refresh_token) {
        throw new Error(
            'refresh_token が返らなかった。既に同意済みのクライアントだと再取得されないことがある。\n' +
            '  https://myaccount.google.com/permissions で当該アプリのアクセスを削除してから再実行してください。',
        );
    }
    saveEnv({ clientId, clientSecret, refreshToken: tok.refresh_token });
    process.stderr.write(
        `✅ 認証完了。refresh token を保存しました: ${OUT_ENV}\n` +
        '   次に `node scripts/analytics/pull-admob.mjs` で収集できます (snapshot にも自動で載ります)。\n',
    );
}

function expandHome(p) {
    return p && p.startsWith('~') ? resolve(homedir(), p.slice(2)) : p;
}

main().catch((err) => {
    process.stderr.write(`AdMob 認証エラー: ${err.message}\n`);
    process.exit(1);
});
