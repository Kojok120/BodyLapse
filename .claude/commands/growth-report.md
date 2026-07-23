---
description: BodyLapse グロース週次レポート。スナップショットを収集し growth-analyst で診断、日付付きレポートを保存する
argument-hint: "[windowDays=30]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash(node scripts/analytics/snapshot.mjs:*), Bash(node scripts/analytics/pull-appstore.mjs:*), Bash(node scripts/analytics/pull-analytics.mjs:*), Bash(node scripts/analytics/pull-admob.mjs:*), Bash(ls:*), Task
---

BodyLapse (写真ベースの身体変化トラッカー) の獲得〜収益ファネルを収集 → 診断 → レポート保存する、グロースループの心拍コマンド。手元で週 1 回叩く運用。

## 手順

1. **収集**: `node scripts/analytics/snapshot.mjs ${1:-30}` を実行する。
   - App Store (共有 ASC キー) で 新規DL / 更新 / 有効サブスクを best-effort 取得。App Analytics と AdMob も best-effort で束ねる。
   - 標準出力の最後の 1 行が保存先パス (`analytics/snapshots/<JST日時>.json`)。標準エラーに要約が出る。
   - **BodyLapse はサーバ側 DB を持たない完全オフラインアプリ**。行動ファネル (セッション/継続) の代替は ASC App Analytics だが、現行キーでは ONGOING レポートリクエストの作成が 403 で未有効 → その段は "未計装" として扱う。
   - AdMob 収益が `configured:false` なら「`node scripts/analytics/admob-auth.mjs` を一度実行して OAuth 同意」と案内 (snapshot 自体は止めない)。

2. **診断**: `growth-analyst` サブエージェントを Task で起動する。プロンプトは「最新スナップショットを診断し、構造化レポートを返せ。ファイルは書くな」。
   - analyst は最新+前回スナップショット・campaigns.md・experiments.md・docs/growth-kpi-tree.md を読んで診断する。

3. **保存**: analyst が返した markdown を `analytics/reports/<今日のJST日付>.md` に保存する (Write)。ファイル冒頭に生成日時とスナップショット窓を付ける。

4. **要約**: ユーザーに 5 行以内で要約する:
   - 今週の新規DLと前回比、有効サブスク数の推移 (North Star)
   - 最大のボトルネック (実数付き)
   - データの限界 (行動データ欠落 / 小 N / 帰属未計装 / ASC 遅延) を 1 行
   - 次アクション: 「第 1 ボトルネックの実験を起票するなら `/growth-experiment`」

## 注意

- これは全体運用の起点。**診断まで**が責務で、施策提案・実装はしない。
- **BodyLapse は行動データ (アプリ内の記録頻度・継続) がサーバに存在しない**。ASC の DL / 有効サブスク / (有効化されれば) App Analytics 継続率 と AdMob 収益だけで語る。DB がある Gymnee と違い、中段ファネルは推定になる旨を必ず添える。
- 有効サブスクは日別の絶対数 (現状 1 桁)。率で断定せず実数で語る。
- スナップショット JSON は集計値のみ (個人情報なし) だが、`analytics/snapshots/` は gitignore 済みでローカル蓄積とする。
