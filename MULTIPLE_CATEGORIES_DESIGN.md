# BodyLapse 複数カテゴリ対応 設計仕様書

## 概要
BodyLapseアプリを拡張し、1日に複数の角度（カテゴリ）から写真を撮影できるようにする。ユーザーは最大4つのカテゴリ（正面＋カスタム3つ）を管理し、各カテゴリごとにガイドラインを設定できる。

## 1. データモデル設計

### 1.1 カテゴリモデル
```swift
// 新規作成: Models/PhotoCategory.swift
struct PhotoCategory: Codable, Identifiable, Equatable {
    let id: String  // "front", "custom1", "custom2", "custom3"
    var name: String  // ユーザーが設定する表示名
    var order: Int  // 表示順序
    var isDefault: Bool  // 正面カテゴリの場合true
    var guideline: BodyGuideline?  // カテゴリごとのガイドライン
    var createdDate: Date
    var isActive: Bool  // 削除せずに非表示にする場合
    
    static let defaultCategory = PhotoCategory(
        id: "front",
        name: "正面",
        order: 0,
        isDefault: true,
        guideline: nil,
        createdDate: Date(),
        isActive: true
    )
}
```

### 1.2 写真モデルの拡張
```swift
// 修正: Models/Photo.swift
struct Photo: Codable, Identifiable {
    let id: UUID
    let captureDate: Date
    let fileName: String
    let categoryId: String  // 新規追加：カテゴリID
    let isFaceBlurred: Bool
    let bodyDetectionConfidence: Double?
    let weight: Double?
    let bodyFatPercentage: Double?
    
    // ファイル名をカテゴリ別に管理
    var fileURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL
            .appendingPathComponent("Photos")
            .appendingPathComponent(categoryId)  // カテゴリ別フォルダ
            .appendingPathComponent(fileName)
    }
}
```

### 1.3 日次メモモデル
```swift
// 新規作成: Models/DailyNote.swift
struct DailyNote: Codable, Identifiable {
    let id: UUID
    let date: Date
    var content: String
    let createdDate: Date
    var lastModifiedDate: Date
}
```

### 1.4 エクスポートデータモデル
```swift
// 新規作成: Models/ExportData.swift
struct ExportData: Codable {
    let version: String  // データフォーマットバージョン
    let exportDate: Date
    let categories: [PhotoCategory]
    let photos: [Photo]
    let videos: [Video]
    let weightEntries: [WeightEntry]
    let dailyNotes: [DailyNote]
    let userSettings: UserSettings
    
    // チェックサム for データ整合性確認
    let checksum: String
}
```

## 2. ストレージ構造の変更

### 2.1 新しいディレクトリ構造
```
Documents/
├── Photos/
│   ├── front/          # 正面カテゴリ
│   │   └── {UUID}.jpg
│   ├── custom1/        # カスタムカテゴリ1
│   │   └── {UUID}.jpg
│   ├── custom2/        # カスタムカテゴリ2
│   │   └── {UUID}.jpg
│   └── custom3/        # カスタムカテゴリ3
│       └── {UUID}.jpg
├── Videos/
│   └── {UUID}.mp4
├── Thumbnails/
│   └── {UUID}.jpg
├── WeightData/
│   └── entries.json
├── Notes/
│   └── daily_notes.json
├── Categories/
│   └── categories.json    # カテゴリ設定
├── photos_metadata.json
├── videos_metadata.json
└── Export/                 # エクスポート用一時ディレクトリ
    └── temp/
```

### 2.2 サービスクラスの変更

#### PhotoStorageService の拡張
```swift
// 主な変更点:
1. savePhoto() にcategoryIdパラメータを追加
2. 1日1枚制限を「1日1カテゴリ1枚」に変更
3. カテゴリ別のフォルダ管理
4. getPhotosForCategory() メソッドの追加
5. getPhotosForDate() がすべてのカテゴリの写真を返すように変更
```

#### 新規: CategoryStorageService
```swift
// 新規作成: Services/CategoryStorageService.swift
class CategoryStorageService {
    static let shared = CategoryStorageService()
    
    func saveCategories(_ categories: [PhotoCategory])
    func loadCategories() -> [PhotoCategory]
    func addCategory(_ category: PhotoCategory)
    func updateCategory(_ category: PhotoCategory)
    func deleteCategory(id: String)  // 実際は isActive = false にする
    func canAddMoreCategories() -> Bool  // 最大3つのカスタムカテゴリ
}
```

#### 新規: DailyNoteStorageService
```swift
// 新規作成: Services/DailyNoteStorageService.swift
actor DailyNoteStorageService {
    static let shared = DailyNoteStorageService()
    
    func saveNote(for date: Date, content: String)
    func getNote(for date: Date) -> DailyNote?
    func deleteNote(for date: Date)
    func getAllNotes() -> [DailyNote]
}
```

#### 新規: ImportExportService
```swift
// 新規作成: Services/ImportExportService.swift
class ImportExportService {
    static let shared = ImportExportService()
    
    // エクスポート
    func exportAllData() async throws -> URL  // ZIPファイルのURL
    func prepareExportData() async throws -> ExportData
    
    // インポート
    func importData(from url: URL) async throws
    func validateImportData(_ data: ExportData) throws
    func mergeImportedData(_ data: ExportData) async throws
}
```

## 3. UI/UX設計

### 3.1 カメラビューの変更
- カテゴリ選択タブをトップに追加
- 各カテゴリのガイドラインを表示
- カテゴリごとの撮影状態を表示（本日撮影済みマーク）

### 3.2 カレンダービューの変更
- カテゴリ選択セグメントコントロールを追加
- 選択中のカテゴリの写真のみ表示
- 日付セルに各カテゴリの撮影状態をドットで表示
- メモアイコンの追加（メモがある日）

### 3.3 設定画面の拡張
```
設定
├── プレミアム管理
├── カテゴリ管理          # 新規
│   ├── カテゴリ一覧
│   ├── カテゴリ追加
│   └── カテゴリ編集
├── データ管理             # 新規
│   ├── エクスポート
│   └── インポート
├── 通知設定
├── 単位設定
└── その他
```

### 3.4 比較ビューの変更
- 各写真にカテゴリ選択を追加
- 同一カテゴリ内での比較を推奨

### 3.5 ギャラリービューの拡張
```
フィルター/ソートオプション:
- カテゴリ別フィルター（複数選択可）
- 日付順ソート（昇順/降順）
- カテゴリ別グループ表示
```

## 4. ビデオ生成レイアウト

### 4.1 シングルカテゴリモード（従来通り）
- 選択したカテゴリの写真のみでタイムラプス生成
- 既存の実装をそのまま使用

### 4.2 サイドバイサイドモード
```
レイアウトパターン:
- 2カテゴリ: 左右分割（50%:50%）
- 3カテゴリ: 上1つ、下2つ（50%:25%:25%）
- 4カテゴリ: 2x2グリッド（各25%）

同期方法:
- 日付で同期（同じ日の写真を並べる）
- 欠損日は前の写真を維持
```

## 5. 実装工程（6週間）

### Week 1-2: データモデルとストレージ基盤
- [ ] PhotoCategoryモデルの実装
- [ ] Photoモデルの拡張（categoryId追加）
- [ ] CategoryStorageServiceの実装
- [ ] PhotoStorageServiceの拡張
- [ ] DailyNoteモデルとStorageServiceの実装
- [ ] 既存データのマイグレーション処理

### Week 3: UI基本実装
- [ ] カテゴリ管理画面の実装
- [ ] CameraViewのカテゴリ対応
- [ ] CalendarViewのカテゴリフィルター
- [ ] カテゴリごとのガイドライン設定

### Week 4: UI詳細実装
- [ ] CompareViewのカテゴリ選択
- [ ] GalleryViewのフィルター/ソート
- [ ] メモ機能のUI実装
- [ ] インタラクティブグラフのカテゴリ維持

### Week 5: ビデオ生成とエクスポート
- [ ] サイドバイサイドビデオ生成
- [ ] ImportExportServiceの実装
- [ ] エクスポート/インポートUI

### Week 6: テストと最適化
- [ ] 統合テスト
- [ ] パフォーマンス最適化
- [ ] エラーハンドリング
- [ ] ユーザビリティテスト

## 6. 技術的考慮事項

### 6.1 パフォーマンス
- カテゴリが増えてもメモリ使用量が線形に増加しないよう注意
- 画像の遅延読み込みを実装
- カテゴリ別のキャッシュ戦略

### 6.2 データ整合性
- カテゴリ削除時の写真処理（論理削除）
- インポート時の重複チェック
- エクスポートデータの検証

### 6.3 UIの一貫性
- カテゴリカラーの統一
- アニメーションの統一
- エラーメッセージの統一

### 6.4 後方互換性
- 既存の単一写真データを「正面」カテゴリに自動マイグレーション
- 設定値のデフォルト値対応

## 7. 追加の実装詳細

### 7.1 有料プラン機能の調整
- 体重/体脂肪率入力は1日1回のみ（カテゴリ共通）
- インタラクティブグラフでカテゴリを維持

### 7.2 通知機能の拡張
- カテゴリ別の撮影リマインダー
- 未撮影カテゴリの通知

### 7.3 エクスポート形式
- ZIP形式で圧縮
- フォルダ構造を維持
- メタデータはJSON形式
- 画像は元の品質を維持

## 8. リスクと対策

### リスク
1. ストレージ容量の増加
2. UI複雑化によるUX低下
3. インポート/エクスポートのデータサイズ

### 対策
1. 画像圧縮オプションの提供
2. シンプルなデフォルト設定
3. 分割エクスポート/インポート対応