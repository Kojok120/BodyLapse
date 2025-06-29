# IconSetCreator アイコン生成チェックリスト

## 生成されるべきファイル一覧

IconSetCreatorで以下のファイルが生成されることを確認してください：

### iPhone用アイコンファイル
- [ ] Icon-20@2x.png (40x40px) - 通知アイコン
- [ ] Icon-20@3x.png (60x60px) - 通知アイコン
- [ ] Icon-29@2x.png (58x58px) - 設定アイコン
- [ ] Icon-29@3x.png (87x87px) - 設定アイコン
- [ ] Icon-40@2x.png (80x80px) - Spotlightアイコン
- [ ] Icon-40@3x.png (120x120px) - Spotlightアイコン
- [ ] Icon-60@2x.png (120x120px) - アプリアイコン
- [ ] Icon-60@3x.png (180x180px) - アプリアイコン
- [ ] Icon-1024.png (1024x1024px) - App Storeアイコン（既存）

## 生成後の作業

### 1. Contents.jsonの更新
IconSetCreatorが自動的にContents.jsonを更新しない場合は、手動で更新が必要です。

### 2. 不要なMacアイコンの削除
現在のContents.jsonにはMac用のアイコンエントリが含まれていますが、アプリはiPhone専用なので削除が必要です。

### 3. Xcodeでの確認
1. Xcodeでプロジェクトを開く
2. Assets.xcassets > AppIconを選択
3. すべての必要なアイコンスロットが埋まっていることを確認
4. 警告やエラーがないことを確認

### 4. ビルドテスト
アイコンを更新後、以下を確認：
- [ ] プロジェクトがクリーンビルドできる
- [ ] シミュレーターでアプリアイコンが正しく表示される
- [ ] 設定アプリでアイコンが正しく表示される

## トラブルシューティング

### もしIconSetCreatorが正しく動作しない場合：
1. **代替ツール**を使用:
   - Bakery (https://apps.apple.com/app/bakery/id1575220747)
   - Icon Set Creator (別のツール)
   - オンラインツール

2. **手動でリサイズ**:
   - Photoshop、Sketch、Figmaなどを使用
   - 各サイズを個別に書き出し

### アイコンの品質チェック：
- エッジがシャープであること
- 小さいサイズでも認識可能であること
- 背景が透明でないこと（Appleの要件）
- 角丸がないこと（システムが自動的に適用）