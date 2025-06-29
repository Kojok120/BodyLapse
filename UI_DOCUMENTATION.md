# BodyLapse UI ドキュメント

## 概要
BodyLapseは、フィットネスの進捗を追跡するiOSアプリです。SwiftUIで構築され、毎日の写真撮影、進捗追跡、タイムラプス動画生成機能を提供します。

## アプリアーキテクチャ

### ナビゲーション構造
```
ContentView (ルート)
├── OnboardingView (初回利用時)
│   ├── ゴール設定
│   ├── ベースライン写真撮影
│   └── アプリロック設定
├── AuthenticationView (アプリロック有効時)
└── MainTabView (メインコンテンツ)
    ├── CalendarView (タブ1)
    ├── CompareView (タブ2)
    ├── CameraView (タブ3)
    ├── GalleryView (タブ4)
    └── SettingsView (タブ5)
```

## 画面詳細

### 1. MainTabView (メインタブビュー)
**ファイル**: `Views/MainTabView.swift`

**構成**:
- 5つのタブを持つTabView
- タブアイコンと名称:
  - Calendar (calendar) - カレンダー
  - Compare (square.on.square) - 比較
  - Photo (camera.fill) - 写真撮影
  - Gallery (photo.stack) - ギャラリー
  - Settings (gearshape.fill) - 設定

**ナビゲーション制御**:
- NotificationCenterを使用した画面遷移
- 写真撮影後はカレンダータブへ自動遷移
- 動画生成後はギャラリータブへ自動遷移

### 2. CalendarView (カレンダービュー)
**ファイル**: `Views/Calendar/CalendarView.swift`

**主要コンポーネント**:
1. **ヘッダー部**
   - 期間選択ボタン (7日/30日/3ヶ月/6ヶ月/1年)
   - カレンダーアイコン (日付選択用)
   - 動画生成ボタン

2. **写真プレビュー部**
   - 選択した日付の写真表示
   - 写真がない場合は「Upload Photo」ボタン表示
   - 画面高さの42% (Premium) または 50% (Free)

3. **進捗表示部**
   - **無料ユーザー**: プログレスバー
     - 写真の有無を色で表示
     - ドラッグ/タップで日付選択
   - **Premiumユーザー**: 体重/体脂肪率グラフ
     - インタラクティブチャート
     - データポイントのタップで詳細表示

**機能**:
- 写真のインポート機能
- 体重/体脂肪率の編集 (Premium)
- 動画生成オプション設定
- バナー広告表示 (無料ユーザー)

### 3. CameraView (カメラビュー)
**ファイル**: `Views/Camera/CameraView.swift`

**主要コンポーネント**:
1. **カメラプレビュー**
   - 全画面表示
   - リアルタイムプレビュー

2. **オーバーレイ要素**
   - カメラ切り替えボタン (右上)
   - ボディガイドライン表示 (設定で制御可能)
   - ボディ検出状態インジケーター

3. **撮影ボタン**
   - 円形ボタン
   - タブバー上部に配置

**機能**:
- フロント/バックカメラ切り替え
- ボディガイドライン表示
- 1日1枚の写真制限
- 写真レビュー画面への遷移
- 体重/体脂肪率入力 (Premium)

### 4. CompareView (比較ビュー)
**ファイル**: `Views/Compare/CompareView.swift`

**レイアウト**:
1. **日付選択ボタン** (上部)
   - Before/After の2つのボタン
   - カレンダーアイコン付き

2. **写真比較セクション** (中央)
   - 2枚の写真を並べて表示
   - 各写真に日付ラベル
   - Premium: 体重/体脂肪率表示

3. **統計表示** (下部)
   - 体重差分表示 (Premium)
   - 体脂肪率差分表示 (Premium)
   - 無料ユーザーにはアップグレード促進メッセージ

**機能**:
- カレンダーポップアップで日付選択
- 写真の自動読み込み
- 差分計算と表示

### 5. GalleryView (ギャラリービュー)
**ファイル**: `Views/Gallery/GalleryView.swift`

**構成**:
1. **セクション切り替え**
   - Videos/Photos のセグメントコントロール
   - スワイプで切り替え可能

2. **グリッド表示**
   - 3列のグリッドレイアウト
   - 月ごとにグループ化
   - スティッキーヘッダー

3. **アイテム表示**
   - **写真**: サムネイル表示
   - **動画**: サムネイル + 再生ボタン + 時間表示

**各アイテムの機能**:
- 3点メニュー (共有/保存/削除)
- タップで詳細表示
- 動画は自動再生・ループ

### 6. SettingsView (設定ビュー)
**ファイル**: `Views/Settings/SettingsView.swift`

**セクション構成**:

1. **写真設定**
   - ボディガイドライン表示切り替え
   - ボディガイドラインリセット
   - 体重単位選択 (kg/lbs)

2. **セキュリティ**
   - アプリロック有効化
   - Face ID/Touch ID設定
   - PIN変更

3. **リマインダー**
   - 毎日のリマインダー設定
   - リマインダー時刻設定

4. **Premiumフィーチャー**
   - サブスクリプション状態表示
   - HealthKit連携 (Premium)
   - アップグレードボタン (無料ユーザー)

5. **データ**
   - 写真エクスポート
   - データクリア

6. **その他**
   - アプリについて
   - プライバシーポリシー
   - 利用規約

## サブビュー

### PhotoReviewView (写真レビュー)
- 撮影した写真のプレビュー
- 保存/キャンセルボタン
- Face Blur オプション

### WeightInputSheet (体重入力シート)
- 体重入力フィールド
- 体脂肪率入力フィールド (オプション)
- HealthKitからの自動入力 (Premium)

### VideoGenerationView (動画生成設定)
- 期間表示
- 速度選択 (Slow/Normal/Fast)
- 品質選択 (Standard/High/Ultra)
- Face Blur オプション
- 推定動画時間表示

### CalendarPopupView (カレンダーポップアップ)
- 月表示カレンダー
- 写真がある日付にドット表示
- 日付範囲制限機能

### ResetGuidelineView (ガイドラインリセット)
- カメラプレビュー
- 新しいガイドライン設定
- 確認フロー

## UI特徴

### レスポンシブデザイン
- iPhone専用に最適化
- iOS 17.0以上対応
- ダークモード対応

### アニメーション
- 画面遷移: スライドアニメーション
- プログレスバー: スムーズなアニメーション
- トースト通知: フェードイン/アウト

### 広告配置 (無料ユーザー)
- バナー広告: Calendar、Compare、Gallery画面の下部
- インタースティシャル広告: 動画生成前

## アクセシビリティ
- VoiceOver対応
- システムフォントサイズ対応
- 高コントラストモード対応

## ナビゲーションフロー

### 主要フロー
1. **写真撮影フロー**
   ```
   CameraView → PhotoReviewView → (WeightInputSheet) → CalendarView
   ```

2. **動画生成フロー**
   ```
   CalendarView → VideoGenerationView → (広告) → 生成 → GalleryView
   ```

3. **初回起動フロー**
   ```
   ContentView → OnboardingView → (AuthenticationSetup) → MainTabView
   ```

4. **認証フロー**
   ```
   ContentView → AuthenticationView → MainTabView
   ```

## 状態管理
- **UserSettingsManager**: アプリ全体の設定管理
- **ViewModelパターン**: 各画面で独立したViewModel使用
- **@StateObject/@ObservedObject**: SwiftUIの状態管理
- **NotificationCenter**: 画面間の通信

## パフォーマンス最適化
- 画像の遅延読み込み
- グリッドビューでのLazyVGrid使用
- サムネイルキャッシング
- バックグラウンドでの画像処理