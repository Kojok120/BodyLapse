# Multiple Photo Categories Implementation Documentation

## 概要
BodyLapseアプリに複数写真カテゴリ機能を実装しました。ユーザーは最大4つのカテゴリ（デフォルトの「Front」＋3つのカスタムカテゴリ）を作成し、それぞれ独立して写真を管理できます。

## 実装された主要機能

### 1. カテゴリ管理システム
- **CategoryStorageService** (`Services/CategoryStorageService.swift`)
  - カテゴリの作成、更新、削除、並び替え機能
  - 最大4つのカテゴリ制限の実装
  - UserDefaultsを使用した永続化

- **CategoryManagementView** (`Views/Settings/CategoryManagementView.swift`)
  - カテゴリの追加・編集・削除UI
  - ドラッグ＆ドロップによる並び替え
  - カテゴリアイコンと色のカスタマイズ

### 2. カテゴリ別写真撮影
- **CameraView** の拡張
  - カテゴリ選択タブの追加
  - カテゴリ別ガイドラインの表示
  - 選択されたカテゴリへの写真保存

- **PhotoStorageService** の拡張
  - カテゴリ別ディレクトリ構造（`Photos/{categoryId}/`）
  - カテゴリIDを含むPhoto構造体の更新

### 3. カレンダービューのカテゴリフィルター
- **CalendarView** の拡張
  - カテゴリタブによるフィルタリング
  - 選択されたカテゴリの写真のみ表示
  - カテゴリ別の進捗トラッキング

### 4. 比較ビューのマルチカテゴリ対応
- **CompareView** の拡張
  - Before/After写真のカテゴリ別選択
  - 異なるカテゴリ間での比較可能

### 5. ギャラリーのカテゴリフィルター
- **GalleryView** の拡張
  - カテゴリ別フィルタリング
  - ソート機能（日付、カテゴリ）
  - フィルター状態の保持

### 6. 日記（メモ）機能
- **DailyNoteStorageService** (`Services/DailyNoteStorageService.swift`)
  - 日付別メモの保存・読み込み・削除
  - JSON形式での永続化

- **MemoEditorView** (`Views/Calendar/MemoEditorView.swift`)
  - メモ編集UI
  - 文字数カウンター（500文字制限）
  - 保存・削除機能

- **CalendarViewModel** の拡張
  - 日記データの管理
  - CalendarPopupViewでのメモ表示・編集

### 7. サイドバイサイドビデオ生成
- **VideoGenerationService** の拡張
  - 複数カテゴリの同時表示レイアウト
  - 2x2グリッドレイアウト（最大4カテゴリ）
  - カテゴリ名のオーバーレイ表示

- **VideoGenerationView** の拡張
  - レイアウト選択（シングル/サイドバイサイド）
  - カテゴリ選択UI
  - プレビュー機能

### 8. インポート/エクスポート機能
- **ImportExportService** (`Services/ImportExportService.swift`)
  - 包括的なデータバックアップ・復元
  - カスタム.bodylapseアーカイブ形式
  - 以下のデータをサポート：
    - 写真（カテゴリ別）
    - ビデオ
    - カテゴリ設定
    - 体重データ
    - 日記（メモ）
    - アプリ設定

- **SimpleZipArchive** (`Services/SimpleZipArchive.swift`)
  - カスタムアーカイブ実装
  - 外部ライブラリ依存なし
  - "BODY"マジックナンバーを使用

- **ImportExportView** (`Views/Settings/ImportExportView.swift`)
  - エクスポートオプション（期間、カテゴリ、データタイプ）
  - インポートオプション（マージ戦略）
  - 進捗表示

## データ構造の変更

### Photo構造体の拡張
```swift
struct Photo: Identifiable, Codable {
    let id: UUID
    let captureDate: Date
    let fileName: String
    let categoryId: String  // 新規追加
    // ... その他のフィールド
}
```

### 新規データモデル
```swift
struct PhotoCategory: Identifiable, Codable {
    let id: String
    var name: String
    var iconName: String
    var colorHex: String
    var order: Int
    var isActive: Bool
}

struct DailyNote: Codable {
    let id: UUID
    let date: Date
    var content: String
    let createdAt: Date
    var updatedAt: Date
}
```

## ファイルシステム構造
```
Documents/
├── Photos/
│   ├── front/          # デフォルトカテゴリ
│   ├── side/           # カスタムカテゴリ1
│   ├── back/           # カスタムカテゴリ2
│   └── detail/         # カスタムカテゴリ3
├── Videos/
├── WeightData/
├── DailyNotes/
└── Categories.json
```

## 技術的な考慮事項

### パフォーマンス最適化
- カテゴリ別のディレクトリ分離により大量の写真でも高速アクセス
- 非同期処理によるUIの応答性維持
- メモリ効率的な画像処理

### 後方互換性
- 既存の写真は自動的にデフォルトカテゴリに割り当て
- マイグレーション処理により既存データの保持

### エラーハンドリング
- カテゴリ数制限のバリデーション
- ファイルアクセスエラーの適切な処理
- インポート/エクスポート時の詳細なエラー情報

## ビルド設定
- iOS 17.0以上が必要（Vision framework APIのため）
- iPhoneのみ対応（iPadサポートなし）
- OpenCVフレームワークの統合

## 今後の拡張可能性
1. カテゴリ数の動的制限
2. カテゴリ別の統計・分析機能
3. カテゴリテンプレート
4. クラウド同期対応
5. カテゴリ別エクスポート設定の保存

## ビルドステータス
✅ ビルド成功確認済み（警告はOpenCV関連のみ）