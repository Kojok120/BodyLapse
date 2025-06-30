# StoreKit Quick Test Guide

## 即座に試すべきこと

### 1. シミュレーターの設定確認
- Settings app → App Store → Sandbox Account
- サインアウトしている状態でOK

### 2. Xcodeの再起動
1. Xcodeを完全に終了
2. 再度開く
3. Product → Clean Build Folder (⇧⌘K)
4. ビルド＆実行

### 3. StoreKit Configuration ファイルの再設定
1. プロジェクトナビゲーターで`BodyLapse.storekit`を選択
2. 右側のFile Inspectorで「Target Membership」を確認
3. 「BodyLapse」にチェックが入っているか確認

### 4. 別のシミュレーターで試す
- 異なるiPhoneモデルのシミュレーターで実行
- iOS 17.0以上を使用

### 5. 実機でテスト（最も確実）
- 実機をMacに接続
- Xcodeで実機を選択してビルド＆実行

## それでも解決しない場合

App Store Connectで以下を確認：
1. アプリのステータスが「Prepare for Submission」以上
2. In-App Purchaseが「Ready to Submit」状態
3. Banking情報が設定済み
4. 税務情報が設定済み