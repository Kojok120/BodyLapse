# マーケ施策 台帳 (campaigns)

BodyLapse のマーケ施策・プロダクト変更 (ASO / 価格 / SNS / 紹介 / 広告頻度 等) を時系列で 1 行ずつ記録する。
`growth-analyst` がこの台帳の施策日と `appstore.downloads.byDayJst` / `appstore.subscriptions.byDayJst` の**相関**を見る土台。
**帰属は未計装**なので、これは相関の手掛かりであって因果の断定材料ではない。
BodyLapse は完全オフラインで行動データが無い分、**施策日と ASC/AdMob の数字の時系列相関が主な分析手段**になる。だからこそ即時記録が効く。

施策をやったら `/campaign-log <説明>` で即追記する (やった当日に記録するほどループの精度が上がる)。

## 書式

パイプ区切りの表に 1 行追記する。既存行は消さない。日付は JST。

| 列 | 意味 |
|---|---|
| date | 施策実施日 (JST, YYYY-MM-DD) |
| channel | `aso` / `price` / `social` / `referral` / `influencer` / `pr` / `community` / `ads` / `other` |
| detail | 何をしたか (簡潔に) |
| quantity | 投稿数・配布数・対象数など (あれば) |
| cost | 概算コスト (あれば、通貨明記) |
| area/target | エリア・セグメント (あれば) |
| notes | キャンペーンリンク/紹介の有無・狙い・相関で見たい指標 |

`channel: ads` = AdMob 広告頻度・配置の変更 (BodyLapse 固有。収益と Premium 転換のトレードオフに直結するので必ず記録する)。

## 台帳

| date | channel | detail | quantity | cost | area/target | notes |
|------|---------|--------|----------|------|-------------|-------|
| (まだ施策の記録はありません。`/campaign-log` で追記します) | | | | | | |
