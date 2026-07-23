# グロース KPI ツリー / ベースライン (BodyLapse)

`growth-analyst` が診断に使う**唯一の物差し**。獲得〜収益ファネルの定義・現状ベースライン・暫定目標を置く。
数字は `analytics/snapshots/*.json` の実フィールドに紐づく。四半期に一度など、実態に合わせて見直す。

BodyLapse は写真ベースの身体変化トラッカー (毎日写真を撮ってタイムラプス動画を作る)。**完全オフライン設計**で、
アプリ内の行動 (撮影頻度・継続・機能利用) は**サーバに一切存在しない**。マネタイズは フリーミアム (Standard/Pro サブスク) + AdMob 広告 (無料ユーザー)。
**公開済みで実ユーザーがいる**ため分析は今から有効。ただし小 N (有効サブスク 1 桁) なので率より実数を追う。

## North Star Metric (今の段階)

**有効サブスク数** (`appstore.subscriptions.latest`)。
BodyLapse は行動データがサーバに無く、継続的な価値提供を測れる唯一の実データが「課金を続けているユーザー数」。
Standard (広告削除) + Pro (広告なし+クラウド+高度動画) の有効サブスク合計を North Star とする。
その日次推移 (`appstore.subscriptions.byDayJst`) の**傾き** (増加/横ばい/解約減) を毎回見る。

- **上流の律速** = **新規DL** (`appstore.downloads.totals.firstDownloads`)。母数が増えないとサブスクも増えない。
- **無料マネタイズ** = **AdMob 推定収益** (`admob.totals.estimatedEarnings`)。OAuth 有効化後に追う。広告頻度と Premium 転換のトレードオフの片側。
- **健全性ガードレール** = 有効サブスクが**解約で減っていないか** (byDayJst の下降)。

> App Analytics (セッション/アクティブ端末/継続率) が有効化されれば、North Star を「週次アクティブ端末」に格上げできる。
> 現状は ONGOING レポートリクエストが現行キーで作成 403 のため**未有効** (下記「データ可用性」参照)。それまでは有効サブスクを North Star にする。

## ファネル定義とベースライン

計測: 2026-07-23 スナップショット時点 / 窓 30 日。**小 N、率は参考値**。実数で読む。

| 段 | フィールド | 現状 (2026-07-23) | 暫定目標 | メモ |
|---|---|---|---|---|
| インプレッション/ページ表示 | `appAnalytics.metrics.*` | **未計装** | App Analytics 有効化 | 現行キーで ONGOING 作成 403。有効化されればファネル最上流が埋まる |
| DL (新規, 30日) | `appstore.downloads.totals.firstDownloads` | **38** | ASO/告知で母数増 | 更新 123 / 再DL 0。ASC 共有キーで自動取得済み |
| 更新 (30日) | `appstore.downloads.totals.updates` | 123 | — | 既存インストールがアップデートを取り込んだ数。継続の**粗い代理** (DAU ではない) |
| [中段: 撮影継続・機能利用] | (サーバ行動データ無し) | **未計装** | App Analytics 継続率 | 完全オフラインのためサーバから見えない。ブラックボックス |
| 有効サブスク (課金) | `appstore.subscriptions.latest` | **3** | 5+ | 期間内に 2→3 に増加 (byDayJst)。**North Star** |
| 広告収益 (無料マネタイズ) | `admob.totals.estimatedEarnings` | **未取得** | OAuth 後にベースライン化 | `admob-auth.mjs` 実行で有効化。無料ユーザーのみ (Premium は広告非表示) |

補助指標 (取れるもの):

| 指標 | フィールド | 現状 (2026-07-23) | メモ |
|---|---|---|---|
| 再DL (30日) | `appstore.downloads.totals.redownloads` | 0 | 一度消して入れ直した数 |
| サブスク日次推移 | `appstore.subscriptions.byDayJst` | 2→3 | 期間内で 1 契約純増。解約減が無いかを毎回確認 |
| proceeds (通貨別) | `appstore.downloads.proceedsByCurrency` | (空) | サブスク proceeds はサブスクレポート側。Sales の proceeds は少額 |

## データ可用性(BodyLapse 特有・誤読注意)

**最重要**: BodyLapse は完全オフラインで、**アプリ内の行動データがサーバに存在しない**。
Gymnee (Supabase に登録〜継続〜課金〜ソーシャルのファネルが集まる) とは根本的に違う。使えるのは 3 ソースのみ:

1. **ASC Sales/Subscription** (実データあり): 新規DL / 更新 / 有効サブスク (日別)。← 現在の主軸。
2. **ASC App Analytics** (行動データの代替候補): セッション / アクティブ端末 / 継続率。
   - **現状未有効**。`GET /v1/apps/{id}/analyticsReportRequests` は現行の共有キー (売上ロール) で **200 (読み取り疎通 OK)** だが、
     行動データの前提である ONGOING レポートリクエストの**作成 (POST) が 403** ("The API key in use does not allow this request")。
     作成には **Admin / App Manager ロール**の ASC キーが要る (または ASC UI で有効化)。
   - 有効化されれば、以後この同じ売上キーで instances を**読める見込み** (読み取りは疎通済み)。生成に初回最大 24〜48h。
   - 収集は `scripts/analytics/pull-analytics.mjs`。既定は作成を試みず `configured:false / setupRequired:true` で理由を返す。`--create` で作成試行 (Admin キー必要)。
3. **AdMob 広告収益** (OAuth 必要): 推定収益 / 表示 / eCPM。`admob-auth.mjs` で一度きり OAuth → `pull-admob.mjs` が収集。未認証なら best-effort スキップ。

→ **ファネル中段 (DL してから撮り続けているか) は現状ブラックボックス**。DL と有効サブスクの比・サブスクの日次推移・(有効化後の) 広告収益から**間接的に**健全性を推定する。診断では必ずこの限界を明示する。

## 目標の考え方

- 小 N のうちは**率より実数の増加**を追う (有効サブスク 3→5、DL 月 38→60、のように)。
- North Star (有効サブスク) を右肩上がりに保ちつつ、解約 (byDayJst の下降) が出ていないかをセットで見る。
- **広告頻度 × Premium 転換のトレードオフ**が固有レバー。広告収益を上げる施策は必ず有効サブスクをガードレールに置く (逆も同様)。
- App Analytics を Admin キーで一度有効化すれば中段ファネル (継続率) が埋まり、North Star を週次アクティブ端末に格上げできる。優先度は高い。
- ここの目標値は暫定。N が増えたら業界水準 (フィットネス系フリーミアムの D7 継続・トライアル転換) と突き合わせて更新する。
