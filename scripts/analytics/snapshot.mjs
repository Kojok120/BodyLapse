#!/usr/bin/env node
// グロース・ハーネス: スナップショット収集オーケストレータ (BodyLapse)。
//
// BodyLapse は完全オフライン設計 (UserDefaults + ファイルシステム、サーバ側 DB 無し) のため、
// 行動データはサーバに存在しない。データソースは 3 本:
//   (a) App Store Connect Sales/Subscription — 新規DL / 更新 / 有効サブスク (実データあり)
//   (b) App Store Connect App Analytics       — セッション/アクティブ端末/継続率 (行動データの代替候補)
//   (c) AdMob 広告収益                        — 無料ユーザーの主収益 (OAuth 必要)
// これらを 1 本で集め、JST 日時付き JSON を analytics/snapshots/<JST日時>.json に保存する。
// この履歴が傾向分析と実験の前後比較 (lift) の土台になる。決定論スクリプト・依存ゼロ。
// 手元で週 1 回叩く運用が基本 (nihongo / Gymnee の snapshot と同じ思想)。
//
//   node scripts/analytics/snapshot.mjs [windowDays=30]
//
// 契約 (nihongo/Gymnee 準拠): 標準出力の最終行 = 保存パス 1 行、標準エラー = 要約。
//   3 ソースとも best-effort (失敗しても configured:false / error を載せて続行)。
//   出力は { schema, generatedAtUtc, windowDays, appstore, appAnalytics, admob }。集計値のみ (個人情報なし)。
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { pullAppStore } from './pull-appstore.mjs';
import { pullAnalytics } from './pull-analytics.mjs';
import { pullAdmob } from './pull-admob.mjs';

async function main() {
    const windowDays = Number(process.argv[2] ?? 30) || 30;

    // 3 ソースとも best-effort。1 つ失敗しても snapshot は保存する (error/note フィールドで残す)。
    // App Analytics は既定で作成を試みない (現行キーは作成 403。読み取り疎通は確認済み)。
    const appstore = await pullAppStore({ windowDays: Math.min(windowDays, 30) });
    const appAnalytics = await pullAnalytics({ windowDays });
    const admob = await pullAdmob({ windowDays });

    const generatedAt = new Date();
    const snapshot = {
        schema: 1,
        generatedAtUtc: generatedAt.toISOString(),
        windowDays,
        appstore,
        appAnalytics,
        admob,
    };

    const scriptDir = dirname(fileURLToPath(import.meta.url));
    const outDir = resolve(scriptDir, '../../analytics/snapshots');
    mkdirSync(outDir, { recursive: true });
    // ファイル名は JST の日時 (分解能・分)。同日複数回実行しても上書きしない。字句順=時系列順。
    const jst = new Date(generatedAt.getTime() + 9 * 60 * 60 * 1000);
    const stamp = jst.toISOString().slice(0, 16).replace('T', '_').replace(':', '');
    const outPath = resolve(outDir, `${stamp}.json`);
    writeFileSync(outPath, JSON.stringify(snapshot, null, 2) + '\n');

    // 標準エラーに要約 (標準出力はパス 1 行のみ = 後段のコマンドが拾いやすい)。
    const asc = appstore;
    const aa = appAnalytics;
    const ad = admob;
    const dlLine = asc.configured
        ? `App Store: ${asc.app?.name ?? asc.app?.label ?? 'OK'}` +
          (asc.downloads?.totals
              ? ` · 新規DL ${asc.downloads.totals.firstDownloads} / 更新 ${asc.downloads.totals.updates}`
              : asc.downloads?.error ? ' · DL取得不可' : '') +
          (asc.subscriptions ? ` · 有効サブスク ${asc.subscriptions.available === false ? 0 : asc.subscriptions.latest}` : '')
        : `App Store: skip (${asc.error})`;
    const aaLine = aa.configured
        ? (aa.pending ? 'App Analytics: 疎通OK・生成待ち (行動データ未着)' : `App Analytics: セッション等 取得 (${Object.keys(aa.metrics ?? {}).join('/')})`)
        : `App Analytics: 未使用 (${aa.setupRequired ? 'ONGOING未作成・現行キーでは作成403' : aa.error})`;
    const adLine = ad.configured
        ? `AdMob: 推定収益 ${ad.totals?.estimatedEarnings} ${ad.currency} / 表示 ${ad.totals?.impressions}`
        : `AdMob: 未使用 (${ad.error ?? 'OAuth未実施 → admob-auth.mjs'})`;

    process.stderr.write(
        [
            `snapshot 保存: ${outPath}`,
            `期間: 直近 ${windowDays} 日 (JST ${stamp})`,
            dlLine,
            aaLine,
            adLine,
        ].join('\n') + '\n',
    );
    process.stdout.write(outPath + '\n');
}

main().catch((err) => {
    console.error(err);
    process.exit(1);
});
