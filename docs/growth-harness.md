# グロース分析ハーネス (BodyLapse)

BodyLapse の獲得〜収益ファネルを継続的に「分析 → 改善」で回す仕組み。
決定論的な収集はスクリプト、判断はエージェント、繰り返し起動はコマンド、状態は台帳、と役割を分ける。
nihongo-web / Gymnee の同型ハーネスを、BodyLapse のデータ事情 (完全オフライン = サーバ行動データ無し) に合わせて移植したもの。

**BodyLapse の前提 (最重要)**: 完全オフライン設計 (UserDefaults + ファイルシステム、ネットワーク無し) のため、
**アプリ内の行動データがサーバに一切存在しない**。データソースは 3 本 ((a) ASC Sales/サブスク (b) ASC App Analytics (c) AdMob) に限られる。
公開済みで実ユーザーがいるため分析は今から有効。ただし小 N (有効サブスク 1 桁) なので率で断定せず実数で語る。

## ループ(毎サイクル回すもの)

```
① 収集 → ② 診断 → ③ 処方 → ④ 実装 → ⑤ 測定 ─┐
   ↑                                            │
   └────────────────────────────────────────────┘
```

| ステージ | 道具 | 実体 |
|---|---|---|
| ① 収集 | script | `scripts/analytics/snapshot.mjs` (ASC Sales/サブスク + App Analytics + AdMob → `analytics/snapshots/<JST日時>.json`) |
| ② 診断 | agent | `growth-analyst` (ファネル構築・ボトルネック特定。処方はしない) |
| ③ 処方 | agent | `growth-strategist` (実在ファイルに紐づく実験を `analytics/experiments.md` に起票) |
| ④ 実装 | 人 / 実装エージェント | 起票された変更を最小差分で実装・ビルド (iPhone 16 / iOS 18.3.1) ・リリース |
| ⑤ 測定 | command | `/growth-measure <id>` (前後スナップショット比較で勝敗判定 → 台帳更新) |
| オーケストレーション | command | `/growth-report` (①→②→レポート保存) |
| 状態 (記憶) | repo files | `analytics/snapshots/` `analytics/campaigns.md` `analytics/experiments.md` `docs/growth-kpi-tree.md` |

## 週次の回し方(手元運用)

```
# 1. 今週の状態を収集して診断レポートを出す
/growth-report

# 2. 第1ボトルネックの実験を起票する
/growth-experiment

# 3. 実験を実装・ビルド・リリースする(人 or 実装エージェント)

# 4. 施策(ASO変更/SNS/価格/広告頻度等)をやったら都度記録する
/campaign-log X で before/after 投稿

# 5. 計測窓が終わったら効果測定する
/growth-measure EXP-20260723-xxxx
```

`/growth-report` は内部で `node scripts/analytics/snapshot.mjs` を叩く。依存ゼロの Node スクリプト (Swift ビルドとは無関係)。

## データソース

| ソース | 何が取れるか | 認証 | 状態 |
|---|---|---|---|
| ASC Sales & Trends | 新規DL / 更新 / 再DL (トップ・オブ・ファネル) | 共有 ASC キー | **稼働** (2026-07-23: 30日で新規DL 38 / 更新 123) |
| ASC Subscription | 有効サブスク数 (Standard+Pro, 日別) | 共有 ASC キー | **稼働** (2026-07-23: 有効サブスク 3, 期間内 2→3) |
| ASC App Analytics | セッション / アクティブ端末 / 継続率 | 共有 ASC キー (読取) + **作成は Admin ロール** | **未有効** (下記) |
| AdMob | 推定収益 / 表示 / eCPM / クリック | Google OAuth (`admob.readonly`) | **未認証** (下記。`admob-auth.mjs` 実行で有効化) |

ASC 資格情報は 3 アプリ共通 (`~/.appstoreconnect/private_keys/AuthKey_*.p8` + `~/.config/growth/asc.env` の KEY_ID/ISSUER/VENDOR_NUMBER)。git には入れない。

### ASC App Analytics の可否 (実測 2026-07-23)

**BodyLapse はサーバ行動データが無いため、セッション/継続率の唯一の代替が ASC App Analytics**。現行キーでの可否を実際に叩いて確認した:

- `GET /v1/apps/{id}/analyticsReportRequests?filter[accessType]=ONGOING` → **HTTP 200** (現行の共有キー=売上ロールで**読み取り疎通 OK**)。ただし ONGOING リクエストは**未作成 (0 件)**。
- `POST /v1/analyticsReportRequests` (ONGOING 作成) → **HTTP 403** `"This request is forbidden for security reasons: The API key in use does not allow this request"`。
  → 現行キーでは App Analytics の**ブートストラップ (ONGOING 作成) ができない**。作成には **Admin / App Manager ロール**の ASC キーが必要 (または ASC UI で有効化)。
- 一度 ONGOING リクエストが作られれば、レポート実体の生成に初回**最大 24〜48h**。生成後は (読み取りは疎通済みなので) この売上キーでも instances を**読める見込み**。

→ 収集は `scripts/analytics/pull-analytics.mjs`。**既定では作成を試みず** `configured:false / setupRequired:true` で理由を返し snapshot を止めない。
Admin ロールのキーが用意できたら `node scripts/analytics/pull-analytics.mjs --create` で ONGOING リクエストを作成 → 数日後の snapshot からセッション/アクティブ端末/継続率が乗り始める。乗ったら KPI ツリーの North Star を「週次アクティブ端末」に格上げできる。

### AdMob の OAuth (未認証ゲート)

AdMob API はサービスアカウント非対応で、AdMob を所有する Google アカウント本人の OAuth 同意が必須。**PSEO の一度きり OAuth と同型**:

```
# 1. Google Cloud Console でデスクトップ型 OAuth クライアントを作り、JSON を ~/.config/growth/admob-oauth-client.json に置く
#    (対象プロジェクトで AdMob API を有効化しておく)
# 2. 一度きり認証 (ブラウザが開く。AdMob 所有アカウント kojokamo120@gmail.com を選ぶ)
node scripts/analytics/admob-auth.mjs
#    → refresh token が ~/.config/growth/admob.env に保存される
# 3. 以後 pull-admob.mjs / snapshot.mjs が refresh token から access token を都度発行して収集 (再ログイン不要)
```

未認証のあいだは `pull-admob.mjs` が `configured:false` + 案内を載せて best-effort スキップする (snapshot は止まらない)。

## スナップショットの契約

`snapshot.mjs` は nihongo / Gymnee 準拠:
- 標準出力の**最終行 = 保存パス 1 行** (後段コマンドが拾いやすい)。進捗・要約は標準エラー。
- 3 ソースとも **best-effort** (失敗しても `error` / `note` フィールドを載せて続行)。
- 出力は `{ schema, generatedAtUtc, windowDays, appstore, appAnalytics, admob }`。**集計値のみ** (個人情報なし)。
- ファイル名は JST 日時 (`YYYY-MM-DD_HHMM.json`)。同日複数回実行しても上書きしない。字句順=時系列順。
- `analytics/snapshots/` は **gitignore 済み**でローカル蓄積とする (履歴は手元に貯める)。

## 保留中: 帰属計装(次サイクルの候補)

行動データが無い分、「どの DL がどの施策由来か」は特に追いにくい。本格化する際の低コスト案:

1. **Apple キャンペーンリンク**: `?ct=x-beforeafter-0723` のような campaign token 付き App Store リンクを SNS/QR に使う → ASC の「キャンペーン」で施策別 DL が割れる。コード変更ゼロ。
2. **App Analytics の有効化 (Admin キー)**: セッション/継続率/取得元 (ソース種別) が取れ、中段ファネルが埋まる。行動が見えない BodyLapse では最優先の計装。
3. **オンボ内 "どこで知りましたか"**: `BodyLapse/Views/Onboarding/OnboardingView.swift` に 1 問追加 (ローカル保存 → 集計は別途)。オフラインなので集計経路は要検討。

## 将来の自動化

現状は手元で週 1 コマンド運用。launchd で週次自動実行にする場合、ASC の静的資格情報 (p8 + env) と AdMob の refresh token (失効しない限り再ログイン不要) を実行環境の env に配線すれば headless 化できる。
まず手運用で 2〜3 週回して、フィールド名・KPI ツリーが安定してから自動化する。

## ファイル一覧

```
scripts/analytics/
  pull-appstore.mjs   # ASC DL/サブスク収集 (JWT 認証・依存ゼロ・3アプリ共通)
  pull-analytics.mjs  # ASC App Analytics 収集+可否調査 (現行キーは読取OK/作成403 → setupRequired)
  pull-admob.mjs      # AdMob 広告収益収集 (OAuth。未認証なら best-effort スキップ)
  admob-auth.mjs      # AdMob 一度きり OAuth (refresh token を ~/.config/growth/admob.env に保存)
  snapshot.mjs        # 上記を束ねて JST 日時付き JSON 保存
analytics/
  snapshots/*.json    # 収集履歴 (集計値のみ・個人情報なし・gitignore 済みでローカル蓄積)
  reports/*.md        # growth-analyst の診断レポート
  campaigns.md        # マーケ施策台帳
  experiments.md      # 実験 PDCA 台帳
.claude/agents/
  growth-analyst.md   # 診断
  growth-strategist.md# 処方 (起票)
.claude/commands/
  growth-report.md    # 収集+診断
  growth-experiment.md# 起票
  growth-measure.md   # 効果測定
  campaign-log.md     # 施策記録
docs/
  growth-kpi-tree.md  # KPI 定義・ベースライン・目標
  growth-harness.md   # このファイル
```
