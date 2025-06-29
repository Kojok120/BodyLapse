# App Store Connect サブスクリプション設定ガイド

このドキュメントでは、BodyLapseアプリのApp Store Connectでのサブスクリプション設定手順を説明します。

## 前提条件

- Apple Developer Program への登録が完了していること
- App Store Connect へのアクセス権限があること
- アプリがApp Store Connectに登録されていること（Bundle ID: com.J.BodyLapse）

## 手順1: App Store Connectにログイン

1. [App Store Connect](https://appstoreconnect.apple.com) にアクセス
2. Apple IDとパスワードでログイン
3. 「マイApp」を選択

## 手順2: アプリを選択

1. BodyLapseアプリを選択
2. 左側のメニューから「App内課金」を選択

## 手順3: サブスクリプショングループの作成

1. 「+」ボタンをクリックして新しいApp内課金を作成
2. 「タイプ」で「自動更新サブスクリプション」を選択
3. 以下の情報を入力：
   - **参照名**: BodyLapse Premium
   - **プロダクトID**: com.J.BodyLapse.premium

## 手順4: サブスクリプションの設定

### 月額サブスクリプション

1. 「+」ボタンをクリックして新しいサブスクリプションを追加
2. 以下の情報を入力：

**基本情報**
- **参照名**: Premium Monthly
- **プロダクトID**: `com.J.BodyLapse.premium.monthly`
- **サブスクリプション期間**: 1か月

**価格設定**
- **価格**: ¥600（Tier 5）
- 他の地域の価格は自動的に設定されます

**ローカライゼーション**
- **表示名**: BodyLapse Premium
- **説明**: 
  ```
  広告なし、透かしなし、体重・体脂肪率トラッキング、詳細なグラフ表示など、すべてのプレミアム機能をご利用いただけます。
  ```

### 年額サブスクリプション

1. 「+」ボタンをクリックして新しいサブスクリプションを追加
2. 以下の情報を入力：

**基本情報**
- **参照名**: Premium Yearly
- **プロダクトID**: `com.J.BodyLapse.premium.yearly`
- **サブスクリプション期間**: 1年

**価格設定**
- **価格**: ¥4,900（Tier 40）
- 他の地域の価格は自動的に設定されます

**ローカライゼーション**
- **表示名**: BodyLapse Premium（年額）
- **説明**: 
  ```
  年額プランで2か月分お得！広告なし、透かしなし、体重・体脂肪率トラッキング、詳細なグラフ表示など、すべてのプレミアム機能をご利用いただけます。
  ```

## 手順5: サブスクリプショングループの設定

1. サブスクリプショングループの設定に移動
2. 以下を設定：

**グループ参照名**: BodyLapse Premium Group

**ローカライゼーション（日本語）**:
- **サブスクリプショングループ表示名**: BodyLapse プレミアム
- **カスタムアプリ名**: BodyLapse

**ローカライゼーション（英語）**:
- **サブスクリプショングループ表示名**: BodyLapse Premium
- **カスタムアプリ名**: BodyLapse

## 手順6: 無料トライアルの設定（オプション）

必要に応じて、イントロダクトリーオファーを設定できます：

1. サブスクリプションを選択
2. 「イントロダクトリーオファー」セクションで「+」をクリック
3. 以下を設定：
   - **期間**: 7日間
   - **価格**: 無料

## 手順7: サブスクリプションステータスURL（オプション）

サーバー間通知を受け取る場合：

1. 「App情報」→「一般情報」に移動
2. 「サブスクリプションステータスURL」に通知を受け取るサーバーのURLを入力

## 手順8: Xcodeプロジェクトの設定

### StoreKit Configuration Fileの作成

1. Xcodeでプロジェクトを開く
2. File → New → File を選択
3. 「StoreKit Configuration File」を選択
4. 名前を「BodyLapse.storekit」として保存

### 設定内容

```json
{
  "identifier": "BodyLapse",
  "nonRenewingSubscriptions": [],
  "products": [],
  "settings": {
    "_applicationInternalID": "YOUR_APP_ID",
    "_developerTeamID": "YOUR_TEAM_ID",
    "_lastSynchronizedDate": 0
  },
  "subscriptionGroups": [
    {
      "id": "21457308",
      "localizations": [
        {
          "description": "BodyLapse Premium",
          "displayName": "BodyLapse Premium",
          "locale": "en_US"
        },
        {
          "description": "BodyLapse プレミアム",
          "displayName": "BodyLapse プレミアム",
          "locale": "ja"
        }
      ],
      "name": "BodyLapse Premium Group",
      "subscriptions": [
        {
          "adHocOffers": [],
          "codeOffers": [],
          "displayPrice": "4.99",
          "familyShareable": false,
          "groupNumber": 1,
          "internalID": "6502445678",
          "introductoryOffer": null,
          "localizations": [
            {
              "description": "No ads, no watermark, weight tracking, and more",
              "displayName": "BodyLapse Premium",
              "locale": "en_US"
            },
            {
              "description": "広告なし、透かしなし、体重トラッキングなど",
              "displayName": "BodyLapse プレミアム",
              "locale": "ja"
            }
          ],
          "productID": "com.J.BodyLapse.premium.monthly",
          "recurringSubscriptionPeriod": "P1M",
          "referenceName": "Premium Monthly",
          "subscriptionGroupID": "21457308",
          "type": "RecurringSubscription"
        },
        {
          "adHocOffers": [],
          "codeOffers": [],
          "displayPrice": "39.99",
          "familyShareable": false,
          "groupNumber": 1,
          "internalID": "6502445679",
          "introductoryOffer": null,
          "localizations": [
            {
              "description": "Save 2 months! No ads, no watermark, weight tracking, and more",
              "displayName": "BodyLapse Premium (Annual)",
              "locale": "en_US"
            },
            {
              "description": "2か月分お得！広告なし、透かしなし、体重トラッキングなど",
              "displayName": "BodyLapse プレミアム（年額）",
              "locale": "ja"
            }
          ],
          "productID": "com.J.BodyLapse.premium.yearly",
          "recurringSubscriptionPeriod": "P1Y",
          "referenceName": "Premium Yearly",
          "subscriptionGroupID": "21457308",
          "type": "RecurringSubscription"
        }
      ]
    }
  ],
  "version": {
    "major": 3,
    "minor": 0
  }
}
```

### Xcodeでの有効化

1. プロジェクト設定を開く
2. 「Signing & Capabilities」タブを選択
3. 「StoreKit Configuration」で作成したファイルを選択

## 手順9: App Store Reviewの準備

### スクリーンショット

サブスクリプション画面のスクリーンショットを準備：
- iPhone用（5.5インチ、6.5インチ）
- iPad用（該当する場合）

### レビューノート

```
このアプリは自動更新サブスクリプションを提供しています。

サブスクリプションの詳細：
- 月額プラン: ¥600/月
- 年額プラン: ¥4,900/年（2か月分お得）

プレミアム機能：
- 広告の非表示
- 動画の透かし除去
- 体重・体脂肪率トラッキング
- 詳細なグラフ表示
- HealthKit連携

テストアカウント：
テスト用のSandboxアカウントを作成してテストしてください。
```

## 手順10: サンドボックステスト

### テストアカウントの作成

1. App Store Connectの「ユーザーとアクセス」に移動
2. 「Sandboxテスター」を選択
3. 「+」ボタンでテスターを追加

### テスト手順

1. iOSデバイスの設定でSandboxアカウントにログイン
2. アプリを実行してサブスクリプション購入をテスト
3. 購入、復元、キャンセルなどの動作を確認

## トラブルシューティング

### 製品が読み込まれない場合

1. Bundle IDが正しいか確認
2. プロダクトIDが完全一致しているか確認
3. App Store Connectで「Ready to Submit」状態になっているか確認
4. 契約・税金・口座情報が完了しているか確認

### サブスクリプションが反映されない場合

1. Transaction.currentEntitlementsが正しく処理されているか確認
2. Transaction.finishが呼ばれているか確認
3. Sandboxアカウントでテストしているか確認

## 本番リリース前のチェックリスト

- [ ] すべてのプロダクトIDが正しく設定されている
- [ ] 価格が正しく設定されている
- [ ] ローカライゼーションが完了している
- [ ] 利用規約とプライバシーポリシーのURLが設定されている
- [ ] サブスクリプションの自動更新に関する説明が記載されている
- [ ] キャンセル方法の説明が記載されている
- [ ] Sandboxでのテストが完了している
- [ ] 本番環境での課金が無効になっている（デバッグビルド）

## 重要な注意事項

1. **審査対応**: Appleの審査では、サブスクリプションの価値が明確に示されていることが重要です
2. **価格変更**: 価格を変更する場合は、既存のサブスクライバーへの通知が必要です
3. **自動更新**: ユーザーがキャンセルするまで自動的に更新されることを明記する必要があります
4. **復元機能**: 必ず「購入の復元」機能を実装してください

## 参考リンク

- [App Store Connect ヘルプ](https://help.apple.com/app-store-connect/)
- [StoreKit 2 ドキュメント](https://developer.apple.com/documentation/storekit)
- [自動更新サブスクリプションのベストプラクティス](https://developer.apple.com/app-store/subscriptions/)