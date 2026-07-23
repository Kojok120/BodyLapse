---
description: 実験の効果測定。experiments.md の実験を、新しいスナップショットの前後比較で勝敗判定し台帳を更新する
argument-hint: "<EXP-id>"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Edit, Bash(node scripts/analytics/snapshot.mjs:*), Bash(ls:*)
---

進行中の実験 `$ARGUMENTS` の効果を測り、`analytics/experiments.md` を更新する。実験の計測窓が終わったら使う。

## 手順

1. `analytics/experiments.md` から id=`$ARGUMENTS` の実験を読む。無ければ一覧を提示して停止。
   - 主要成功指標 (スナップショットのフィールド)、baseline (起票時の値)、計測窓、ガードレールを取得する。
2. 最新スナップショットを用意する:
   - 今日のスナップショットが `analytics/snapshots/` に無ければ `node scripts/analytics/snapshot.mjs 30` を実行して作る。
   - 実験開始時点に近いスナップショット (start) と最新 (end) を選ぶ。ファイル名は JST 日時なので字句順で選べる。
3. **前後比較**: 成功指標の start→end を出す。実数と率の両方。小 N の場合は「実数変化」を主に、率は参考。
4. **判定**: 目標達成なら `win`、悪化なら `loss`、有意差なしなら `flat`。ガードレール指標が悪化していれば、成功指標が改善していても `guardrail-breach` を併記。
   - **BodyLapse 固有ガードレール**: 広告系の実験なら「Premium 転換 (`appstore.subscriptions.latest`) を落としていないか」「AdMob 収益との差引で純増か」を必ず併記する。
5. **台帳更新**: 該当実験エントリの status を `completed` にし、`result:` に {判定・start値・end値・lift・所感 1 行・測定日} を追記する (Edit)。既存フィールドは壊さない。
6. ユーザーに判定と次の一手 (勝ち→横展開/恒久化、負け→仮説棄却して次のボトルネックへ) を 3 行で案内する。

## 注意

- 帰属が未計装なので、指標変化が「その実験のおかげ」と断定しない。同時期の campaigns.md の施策も併記し、交絡を明示する。
- **BodyLapse は行動データがサーバに無い**。有効サブスク・DL・AdMob 収益は数日遅延で ASC / AdMob に反映される。end 値がまだ確定していない可能性を添える。
- 有効サブスクは絶対数が 1 桁。1 回の測定で決めきらず「継続観測」も選択肢に入れる。
