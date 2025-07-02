# BodyLapse インポート/エクスポート機能 詳細仕様書

## 1. 概要

ユーザーが端末変更やアプリ再インストール時にデータを移行できるよう、完全なデータのエクスポート/インポート機能を提供する。

## 2. エクスポート仕様

### 2.1 エクスポート対象データ

#### 必須データ
- **写真**: すべてのカテゴリの写真ファイル（オリジナル品質）
- **写真メタデータ**: 撮影日時、カテゴリ、体重、体脂肪率など
- **カテゴリ設定**: カスタムカテゴリ名、ガイドライン、順序
- **体重データ**: すべての体重・体脂肪率記録
- **日次メモ**: すべてのメモデータ

#### オプションデータ（設定で選択可能）
- **生成済みビデオ**: タイムラプス動画ファイル
- **ビデオメタデータ**: 生成日時、使用した写真範囲など
- **アプリ設定**: 通知設定、単位設定、プレミアム状態など
- **ガイドライン画像**: 各カテゴリのガイドライン元画像

### 2.2 エクスポート形式

```
BodyLapse_Export_YYYYMMDD_HHMMSS.bodylapse
└── package/
    ├── manifest.json         # パッケージ情報
    ├── data/
    │   ├── photos/
    │   │   ├── front/       # カテゴリ別フォルダ
    │   │   │   └── *.jpg
    │   │   ├── custom1/
    │   │   └── ...
    │   ├── videos/          # オプション
    │   │   └── *.mp4
    │   ├── thumbnails/      # オプション
    │   │   └── *.jpg
    │   └── guidelines/      # オプション
    │       └── *.jpg
    └── metadata/
        ├── photos.json      # 写真メタデータ
        ├── videos.json      # ビデオメタデータ
        ├── categories.json  # カテゴリ設定
        ├── weights.json     # 体重データ
        ├── notes.json       # 日次メモ
        └── settings.json    # アプリ設定
```

### 2.3 manifest.json の構造

```json
{
  "version": "1.0",
  "format": "bodylapse-export",
  "exportDate": "2025-01-01T10:00:00Z",
  "appVersion": "1.0.0",
  "deviceInfo": {
    "model": "iPhone 15",
    "osVersion": "iOS 17.0"
  },
  "dataChecksum": {
    "algorithm": "SHA256",
    "value": "..."
  },
  "contents": {
    "photos": {
      "count": 365,
      "categories": ["front", "side", "back"],
      "dateRange": {
        "start": "2024-01-01",
        "end": "2024-12-31"
      }
    },
    "videos": {
      "count": 12,
      "included": true
    },
    "weights": {
      "count": 365
    },
    "notes": {
      "count": 50
    }
  },
  "options": {
    "includeVideos": true,
    "includeSettings": true,
    "compressionLevel": "original"  // original, high, medium
  }
}
```

### 2.4 エクスポート処理フロー

```swift
// ImportExportService.swift の主要メソッド

func exportAllData(options: ExportOptions) async throws -> URL {
    // 1. 進捗画面を表示
    showExportProgress()
    
    // 2. 一時ディレクトリを作成
    let tempDir = createTempExportDirectory()
    
    // 3. データを収集
    let exportData = try await collectExportData(options)
    
    // 4. データを一時ディレクトリにコピー
    try await copyPhotosToExport(tempDir, exportData.photos)
    if options.includeVideos {
        try await copyVideosToExport(tempDir, exportData.videos)
    }
    
    // 5. メタデータをJSON形式で保存
    try await saveMetadata(tempDir, exportData)
    
    // 6. manifest.jsonを生成
    let manifest = createManifest(exportData, options)
    try saveManifest(tempDir, manifest)
    
    // 7. ZIPファイルに圧縮（.bodylapseカスタム拡張子）
    let zipURL = try await compressToZip(tempDir)
    
    // 8. チェックサムを検証
    try validateChecksum(zipURL, manifest.dataChecksum)
    
    // 9. 一時ディレクトリをクリーンアップ
    cleanupTempDirectory(tempDir)
    
    return zipURL
}
```

### 2.5 エクスポートUI/UX

```
設定画面
└── データ管理
    └── エクスポート
        ├── エクスポート内容選択
        │   ├── [✓] 写真とメタデータ（必須）
        │   ├── [✓] カテゴリ設定（必須）
        │   ├── [✓] 体重データ（必須）
        │   ├── [✓] メモ（必須）
        │   ├── [ ] 生成済みビデオ
        │   ├── [ ] アプリ設定
        │   └── [ ] ガイドライン画像
        ├── 圧縮レベル
        │   ├── ( ) オリジナル品質（推奨）
        │   ├── ( ) 高品質（ファイルサイズ削減）
        │   └── ( ) 中品質（大幅にサイズ削減）
        └── [エクスポート開始]ボタン

エクスポート進捗画面
├── プログレスバー
├── 現在の処理: "写真をコピー中... (150/365)"
├── 推定残り時間: "約2分"
└── [キャンセル]ボタン
```

### 2.6 エクスポート完了後の処理

1. **共有オプション**
   - AirDrop
   - iCloud Drive
   - Google Drive
   - その他のファイル共有アプリ

2. **ファイル保存場所**
   - Filesアプリの「BodyLapse」フォルダ
   - ユーザーが選択した任意の場所

## 3. インポート仕様

### 3.1 インポートオプション

```swift
struct ImportOptions {
    // データ選択
    var importPhotos: Bool = true
    var importVideos: Bool = true
    var importWeights: Bool = true
    var importNotes: Bool = true
    var importCategories: Bool = true
    var importSettings: Bool = false
    
    // 競合解決方法
    var photoConflictResolution: ConflictResolution = .skip
    var weightConflictResolution: ConflictResolution = .merge
    var noteConflictResolution: ConflictResolution = .replace
    
    enum ConflictResolution {
        case skip      // 既存データを保持
        case replace   // インポートデータで上書き
        case merge     // データをマージ（可能な場合）
        case askUser   // ユーザーに確認
    }
}
```

### 3.2 インポート処理フロー

```swift
func importData(from fileURL: URL, options: ImportOptions) async throws {
    // 1. ファイル検証
    guard isValidBodyLapseFile(fileURL) else {
        throw ImportError.invalidFileFormat
    }
    
    // 2. 一時ディレクトリに解凍
    let tempDir = try await unzipToTempDirectory(fileURL)
    
    // 3. manifest.jsonを読み込み
    let manifest = try loadManifest(from: tempDir)
    
    // 4. データ整合性チェック
    try validateDataIntegrity(tempDir, manifest)
    
    // 5. バージョン互換性チェック
    try checkVersionCompatibility(manifest)
    
    // 6. インポートプレビューを表示
    let preview = try await generateImportPreview(tempDir, manifest)
    guard await showImportConfirmation(preview) else { return }
    
    // 7. データインポート実行
    try await performImport(tempDir, manifest, options)
    
    // 8. クリーンアップ
    cleanupTempDirectory(tempDir)
    
    // 9. 完了通知
    showImportSuccess(preview)
}

private func performImport(_ tempDir: URL, _ manifest: Manifest, _ options: ImportOptions) async throws {
    // カテゴリのインポート（最初に実行）
    if options.importCategories {
        try await importCategories(from: tempDir)
    }
    
    // 写真のインポート
    if options.importPhotos {
        try await importPhotos(from: tempDir, conflictResolution: options.photoConflictResolution)
    }
    
    // 体重データのインポート
    if options.importWeights {
        try await importWeights(from: tempDir, conflictResolution: options.weightConflictResolution)
    }
    
    // メモのインポート
    if options.importNotes {
        try await importNotes(from: tempDir, conflictResolution: options.noteConflictResolution)
    }
    
    // ビデオのインポート
    if options.importVideos {
        try await importVideos(from: tempDir)
    }
    
    // 設定のインポート
    if options.importSettings {
        try await importSettings(from: tempDir)
    }
}
```

### 3.3 競合処理の詳細

#### 写真の競合
```swift
// 同じ日付・カテゴリに既に写真が存在する場合
switch conflictResolution {
case .skip:
    // インポートをスキップ
case .replace:
    // 既存の写真を削除してインポート
case .merge:
    // 写真の場合はマージ不可なのでreplaceと同じ
case .askUser:
    // ユーザーに選択させる
    let choice = await showPhotoConflictDialog(existing, importing)
}
```

#### 体重データの競合
```swift
// 同じ日付に体重データが存在する場合
switch conflictResolution {
case .skip:
    // インポートをスキップ
case .replace:
    // 既存データを上書き
case .merge:
    // より新しいタイムスタンプのデータを採用
case .askUser:
    // ユーザーに選択させる
}
```

### 3.4 インポートUI/UX

```
インポート画面フロー:

1. ファイル選択
   └── Filesアプリから.bodylapseファイルを選択

2. インポートプレビュー
   ├── インポート内容サマリー
   │   ├── 写真: 365枚（3カテゴリ）
   │   ├── 期間: 2024/1/1 - 2024/12/31
   │   ├── 体重データ: 365件
   │   ├── メモ: 50件
   │   └── ビデオ: 12本
   ├── 競合検出結果
   │   └── "15件の写真が既存データと競合しています"
   └── [インポート設定] [インポート開始]

3. インポート設定（オプション）
   ├── インポートする項目
   │   ├── [✓] 写真
   │   ├── [✓] 体重データ
   │   ├── [✓] メモ
   │   ├── [ ] ビデオ
   │   └── [ ] アプリ設定
   └── 競合時の処理
       ├── 写真: [スキップ▼]
       ├── 体重: [マージ▼]
       └── メモ: [置換▼]

4. インポート進捗
   ├── プログレスバー
   ├── "写真をインポート中... (150/365)"
   └── [キャンセル]（データ整合性を保つため途中キャンセル不可）

5. 完了画面
   ├── "インポートが完了しました"
   ├── インポート結果サマリー
   │   ├── 写真: 350枚をインポート（15枚スキップ）
   │   ├── 体重: 365件をマージ
   │   └── メモ: 50件を追加
   └── [完了]
```

## 4. エラーハンドリング

### 4.1 エクスポート時のエラー

```swift
enum ExportError: LocalizedError {
    case insufficientStorage(required: Int64, available: Int64)
    case photoNotFound(photoId: String)
    case compressionFailed(reason: String)
    case checksumMismatch
    
    var errorDescription: String? {
        switch self {
        case .insufficientStorage(let required, let available):
            return "ストレージ容量が不足しています。必要: \(required/1024/1024)MB、利用可能: \(available/1024/1024)MB"
        // ... 他のケース
        }
    }
}
```

### 4.2 インポート時のエラー

```swift
enum ImportError: LocalizedError {
    case invalidFileFormat
    case corruptedData(file: String)
    case incompatibleVersion(fileVersion: String, appVersion: String)
    case checksumMismatch
    case partialImportFailure(succeeded: Int, failed: Int)
}
```

## 5. セキュリティとプライバシー

### 5.1 データ保護
- エクスポートファイルは暗号化オプションを提供（Face ID/Touch IDで保護）
- インポート時は整合性チェックサムで改ざん検出
- 一時ファイルは処理後即座に削除

### 5.2 プライバシー配慮
- エクスポート時に顔ぼかし状態を維持
- 個人を特定できる情報（位置情報など）は含めない
- アプリ内購入情報は含めない（再購入復元を使用）

## 6. パフォーマンス最適化

### 6.1 大容量データ対応
- ストリーミング処理で大量の写真に対応
- バックグラウンド処理で UI の応答性を維持
- 進捗表示と推定時間の表示

### 6.2 エラー回復
- 部分的なインポート失敗時の復旧機能
- 中断されたエクスポートの再開機能
- トランザクション処理でデータ整合性を保証

## 7. 将来の拡張性

### 7.1 クラウド連携（将来実装）
- iCloud Drive への自動バックアップ
- 複数デバイス間での同期

### 7.2 増分バックアップ（将来実装）
- 前回のエクスポート以降の差分のみエクスポート
- バックアップ履歴の管理