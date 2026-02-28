import Foundation
import UIKit

class ImportExportService {
    static let shared = ImportExportService()
    
    private init() {}
    
    enum ImportExportError: LocalizedError {
        case exportFailed(String)
        case importFailed(String)
        case invalidFormat
        case noDataToExport
        case fileNotFound
        case zipOperationFailed
        
        var errorDescription: String? {
            switch self {
            case .exportFailed(let reason):
                return String(format: "import_export.error_export_failed".localized, reason)
            case .importFailed(let reason):
                return String(format: "import_export.error_import_failed".localized, reason)
            case .invalidFormat:
                return "import_export.error_invalid_format".localized
            case .noDataToExport:
                return "import_export.error_no_data".localized
            case .fileNotFound:
                return "import_export.error_file_not_found".localized
            case .zipOperationFailed:
                return "import_export.error_zip_failed".localized
            }
        }
    }
    
    struct ExportOptions {
        let includePhotos: Bool
        let includeVideos: Bool
        let includeSettings: Bool
        let includeWeightData: Bool
        let includeNotes: Bool
        let dateRange: ClosedRange<Date>?
        let categories: [String]? // nil means all categories
        
        static let all = ExportOptions(
            includePhotos: true,
            includeVideos: true,
            includeSettings: true,
            includeWeightData: true,
            includeNotes: true,
            dateRange: nil,
            categories: nil
        )
    }
    
    struct ImportOptions {
        let mergeStrategy: MergeStrategy
        let importPhotos: Bool
        let importVideos: Bool
        let importSettings: Bool
        let importWeightData: Bool
        let importNotes: Bool
        
        enum MergeStrategy: String, CaseIterable {
            case skip          // Skip existing data
            case replace       // Replace existing data
        }
        
        static let `default` = ImportOptions(
            mergeStrategy: .skip,
            importPhotos: true,
            importVideos: true,
            importSettings: false,
            importWeightData: true,
            importNotes: true
        )
    }
    
    struct ExportManifest: Codable {
        let version: String
        let exportDate: Date
        let appVersion: String
        let deviceInfo: DeviceInfo
        let dataInfo: DataInfo
        
        struct DeviceInfo: Codable {
            let model: String
            let systemVersion: String
            let locale: String
        }
        
        struct DataInfo: Codable {
            let photoCount: Int
            let videoCount: Int
            let categoryCount: Int
            let weightEntryCount: Int
            let noteCount: Int
            let dateRange: DateRange?
        }
        
        struct DateRange: Codable {
            let start: Date
            let end: Date
        }
    }
    
    // MARK: - エクスポート
    
    func exportData(
        options: ExportOptions,
        progress: @escaping (Float) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        Task {
            await self.performExport(options: options, progress: progress, completion: completion)
        }
    }
    
    private func performExport(
        options: ExportOptions,
        progress: @escaping (Float) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) async {
            
            do {
                // 一時ディレクトリを作成
                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("BodyLapseExport_\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: tempDir) }
                
                var totalSteps: Float = 0
                var currentStep: Float = 0
                
                // 総ステップ数を計算
                if options.includePhotos {
                    totalSteps += Float(PhotoStorageService.shared.photos.count)
                }
                if options.includeVideos {
                    totalSteps += Float(VideoStorageService.shared.videos.count)
                }
                totalSteps += 5 // For other operations
                
                // フォルダ構造を作成
                let photosDir = tempDir.appendingPathComponent("photos")
                let videosDir = tempDir.appendingPathComponent("videos")
                let dataDir = tempDir.appendingPathComponent("data")
                
                try FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: videosDir, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
                
                currentStep += 1
                progress(currentStep / totalSteps)
                
                // 写真をエクスポート
                var exportedPhotos: [Photo] = []
                if options.includePhotos {
                    exportedPhotos = try self.exportPhotos(
                        to: photosDir,
                        options: options,
                        progress: { photoProgress in
                            let stepProgress = currentStep + (photoProgress * Float(PhotoStorageService.shared.photos.count))
                            progress(stepProgress / totalSteps)
                        }
                    )
                    currentStep += Float(PhotoStorageService.shared.photos.count)
                }
                
                // 動画をエクスポート
                var exportedVideos: [Video] = []
                if options.includeVideos {
                    exportedVideos = try self.exportVideos(
                        to: videosDir,
                        options: options,
                        progress: { videoProgress in
                            let stepProgress = currentStep + (videoProgress * Float(VideoStorageService.shared.videos.count))
                            progress(stepProgress / totalSteps)
                        }
                    )
                    currentStep += Float(VideoStorageService.shared.videos.count)
                }
                
                // カテゴリーをエクスポート
                let categories = CategoryStorageService.shared.getActiveCategories()
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let categoriesData = try encoder.encode(categories)
                try categoriesData.write(to: dataDir.appendingPathComponent("categories.json"))
                
                currentStep += 1
                progress(currentStep / totalSteps)
                
                // 体重データをエクスポート
                if options.includeWeightData {
                    let weightEntries = try await WeightStorageService.shared.loadEntries()
                    let filteredEntries = self.filterWeightEntries(weightEntries, options: options)
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    let weightData = try encoder.encode(filteredEntries)
                    try weightData.write(to: dataDir.appendingPathComponent("weight_data.json"))
                }
                
                currentStep += 1
                progress(currentStep / totalSteps)
                
                // ノートをエクスポート
                if options.includeNotes {
                    let notes = await DailyNoteStorageService.shared.getAllNotes()
                    let filteredNotes = self.filterNotes(notes, options: options)
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    let notesData = try encoder.encode(filteredNotes)
                    try notesData.write(to: dataDir.appendingPathComponent("notes.json"))
                }
                
                currentStep += 1
                progress(currentStep / totalSteps)
                
                // リクエストに応じて設定をエクスポート
                if options.includeSettings {
                    let settings = await MainActor.run {
                        UserSettingsManager.shared.settings
                    }
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    let settingsData = try encoder.encode(settings)
                    try settingsData.write(to: dataDir.appendingPathComponent("settings.json"))
                }
                
                // マニフェストを作成
                let manifest = self.createManifest(
                    photos: exportedPhotos,
                    videos: exportedVideos,
                    categories: categories,
                    options: options
                )
                let manifestEncoder = JSONEncoder()
                manifestEncoder.dateEncodingStrategy = .iso8601
                let manifestData = try manifestEncoder.encode(manifest)
                try manifestData.write(to: tempDir.appendingPathComponent("manifest.json"))
                
                currentStep += 1
                progress(currentStep / totalSteps)
                
                // ZIPファイルを作成
                let zipPath = FileManager.default.temporaryDirectory
                    .appendingPathComponent("BodyLapse_Export_\(Date().timeIntervalSince1970).bodylapse")
                
                let success = SimpleZipArchive.createZipFile(
                    atPath: zipPath.path,
                    withContentsOfDirectory: tempDir.path,
                    keepParentDirectory: false
                )
                
                if success {
                    DispatchQueue.main.async {
                        completion(.success(zipPath))
                    }
                } else {
                    throw ImportExportError.zipOperationFailed
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
    }
    
    // MARK: - インポート
    
    func importData(
        from url: URL,
        options: ImportOptions,
        progress: @escaping (Float) -> Void,
        completion: @escaping (Result<ImportSummary, Error>) -> Void
    ) {
        Task {
            await self.performImport(from: url, options: options, progress: progress, completion: completion)
        }
    }
    
    private func performImport(
        from url: URL,
        options: ImportOptions,
        progress: @escaping (Float) -> Void,
        completion: @escaping (Result<ImportSummary, Error>) -> Void
    ) async {
        print("[ImportExport] Starting import from: \(url.path)")
        
        do {
                // 展開用の一時ディレクトリを作成
                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("BodyLapseImport_\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: tempDir) }
                
                // 展開前にファイルサイズを検証
                print("[ImportExport] Validating file size...")
                let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
                print("[ImportExport] File size: \(fileSize) bytes")
                guard fileSize > 0 && fileSize < 500_000_000 else { // Max 500MB
                    throw ImportExportError.invalidFormat
                }
                
                // 検証付きでZIPを展開
                print("[ImportExport] Extracting archive...")
                guard SimpleZipArchive.unzipFile(
                    atPath: url.path,
                    toDestination: tempDir.path
                ) else {
                    print("[ImportExport] Archive extraction failed")
                    throw ImportExportError.zipOperationFailed
                }
                print("[ImportExport] Archive extracted successfully")
                
                // マニフェストを読み取り
                let manifestPath = tempDir.appendingPathComponent("manifest.json")
                guard FileManager.default.fileExists(atPath: manifestPath.path) else {
                    throw ImportExportError.invalidFormat
                }
                
                // マニフェストデータを安全に読み取り・検証
                print("[ImportExport] Reading manifest...")
                let manifest = try safelyDecodeJSON(ExportManifest.self, from: manifestPath)
                print("[ImportExport] Manifest loaded successfully")
                print("[ImportExport] - Version: \(manifest.version)")
                print("[ImportExport] - Export date: \(manifest.exportDate)")
                print("[ImportExport] - Photos: \(manifest.dataInfo.photoCount)")
                print("[ImportExport] - Videos: \(manifest.dataInfo.videoCount)")
                print("[ImportExport] - Categories: \(manifest.dataInfo.categoryCount)")
                
                // デバッグ: 展開されたファイルを一覧表示
                print("[ImportExport] Temp directory structure:")
                if let enumerator = FileManager.default.enumerator(atPath: tempDir.path) {
                    while let element = enumerator.nextObject() as? String {
                        print("[ImportExport]   - \(element)")
                    }
                }
                
                var summary = ImportSummary()
                var totalSteps: Float = 0
                var currentStep: Float = 0
                
                // デバッグ: インポートオプション
                print("[ImportExport] Import options:")
                print("[ImportExport] - Merge strategy: \(options.mergeStrategy)")
                print("[ImportExport] - Import photos: \(options.importPhotos)")
                print("[ImportExport] - Import videos: \(options.importVideos)")
                print("[ImportExport] - Import settings: \(options.importSettings)")
                print("[ImportExport] - Import weight data: \(options.importWeightData)")
                print("[ImportExport] - Import notes: \(options.importNotes)")
                
                // 総ステップ数を計算
                if options.importPhotos {
                    totalSteps += Float(manifest.dataInfo.photoCount)
                }
                if options.importVideos {
                    totalSteps += Float(manifest.dataInfo.videoCount)
                }
                totalSteps += 5 // For other operations
                
                // 最初にカテゴリーをインポート
                let categoriesPath = tempDir.appendingPathComponent("data/categories.json")
                print("[ImportExport] Checking for categories at: \(categoriesPath.path)")
                if FileManager.default.fileExists(atPath: categoriesPath.path) {
                    print("[ImportExport] Categories file found, loading...")
                    let categories = try safelyDecodeJSON([PhotoCategory].self, from: categoriesPath)
                    print("[ImportExport] Loaded \(categories.count) categories")
                    summary.categoriesImported = try self.importCategories(categories, options: options)
                    print("[ImportExport] Categories imported: \(summary.categoriesImported)")
                } else {
                    print("[ImportExport] Categories file not found")
                }
                
                currentStep += 1
                progress(currentStep / totalSteps)
                
                // 写真をインポート
                if options.importPhotos {
                    let photosDir = tempDir.appendingPathComponent("photos")
                    print("[ImportExport] Starting photo import from: \(photosDir.path)")
                    print("[ImportExport] Photos directory exists: \(FileManager.default.fileExists(atPath: photosDir.path))")
                    
                    do {
                        summary.photosImported = try self.importPhotos(
                            from: photosDir,
                            options: options,
                            progress: { photoProgress in
                                let stepProgress = currentStep + (photoProgress * Float(manifest.dataInfo.photoCount))
                                progress(stepProgress / totalSteps)
                            }
                        )
                        print("[ImportExport] Photos imported: \(summary.photosImported)")
                    } catch {
                        print("[ImportExport] Error importing photos: \(error)")
                        throw error
                    }
                    currentStep += Float(manifest.dataInfo.photoCount)
                }
                
                // 動画をインポート
                if options.importVideos {
                    let videosDir = tempDir.appendingPathComponent("videos")
                    print("[ImportExport] Starting video import from: \(videosDir.path)")
                    print("[ImportExport] Videos directory exists: \(FileManager.default.fileExists(atPath: videosDir.path))")
                    
                    do {
                        summary.videosImported = try await self.importVideos(
                            from: videosDir,
                            options: options,
                            progress: { videoProgress in
                                let stepProgress = currentStep + (videoProgress * Float(manifest.dataInfo.videoCount))
                                progress(stepProgress / totalSteps)
                            }
                        )
                        print("[ImportExport] Videos imported: \(summary.videosImported)")
                    } catch {
                        print("[ImportExport] Error importing videos: \(error)")
                        throw error
                    }
                    currentStep += Float(manifest.dataInfo.videoCount)
                }
                
                // 体重データをインポート
                if options.importWeightData {
                    let weightPath = tempDir.appendingPathComponent("data/weight_data.json")
                    if FileManager.default.fileExists(atPath: weightPath.path) {
                        let entries = try safelyDecodeJSON([WeightEntry].self, from: weightPath)
                        summary.weightEntriesImported = try await self.importWeightEntries(entries, options: options)
                    }
                }
                
                currentStep += 1
                progress(currentStep / totalSteps)
                
                // ノートをインポート
                if options.importNotes {
                    let notesPath = tempDir.appendingPathComponent("data/notes.json")
                    if FileManager.default.fileExists(atPath: notesPath.path) {
                        let notes = try safelyDecodeJSON([DailyNote].self, from: notesPath)
                        summary.notesImported = try await self.importNotes(notes, options: options)
                    }
                }
                
                currentStep += 1
                progress(currentStep / totalSteps)
                
                // リクエストに応じて設定をインポート
                if options.importSettings {
                    let settingsPath = tempDir.appendingPathComponent("data/settings.json")
                    if FileManager.default.fileExists(atPath: settingsPath.path) {
                        let settings = try safelyDecodeJSON(UserSettings.self, from: settingsPath)
                        await MainActor.run {
                            UserSettingsManager.shared.settings = settings
                        }
                        summary.settingsImported = true
                    }
                }
                
                print("[ImportExport] Import completed - Summary:")
                print("[ImportExport] - Photos imported: \(summary.photosImported)")
                print("[ImportExport] - Videos imported: \(summary.videosImported)")
                print("[ImportExport] - Categories imported: \(summary.categoriesImported)")
                print("[ImportExport] - Weight entries imported: \(summary.weightEntriesImported)")
                print("[ImportExport] - Notes imported: \(summary.notesImported)")
                print("[ImportExport] - Total items: \(summary.totalItemsImported)")
                
                let finalSummary = summary
                await MainActor.run {
                    completion(.success(finalSummary))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
    }
    
    // MARK: - ヘルパーメソッド
    
    private func safelyDecodeJSON<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        // ファイルの存在とサイズを検証
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ImportExportError.fileNotFound
        }
        
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
        guard fileSize > 0 && fileSize < 10_000_000 else { // Max 10MB for JSON
            throw ImportExportError.invalidFormat
        }
        
        // ファイルデータを安全に読み取り
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard data.count > 0 else {
            throw ImportExportError.invalidFormat
        }
        
        // 適切な設定でデコーダーを作成
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // まずISO8601でデコードを試行
        do {
            return try decoder.decode(type, from: data)
        } catch {
            // ISO8601が失敗した場合、タイムスタンプで試行（後方互換性のため）
            print("ISO8601 decode failed, trying timestamp strategy: \(error)")
            decoder.dateDecodingStrategy = .secondsSince1970
            do {
                return try decoder.decode(type, from: data)
            } catch {
                print("JSON decode error for \(type): \(error)")
                throw ImportExportError.invalidFormat
            }
        }
    }
    
    private func exportPhotos(
        to directory: URL,
        options: ExportOptions,
        progress: @escaping (Float) -> Void
    ) throws -> [Photo] {
        var exportedPhotos: [Photo] = []
        let photos = PhotoStorageService.shared.photos
        
        // オプションに基づいて写真をフィルター
        let filteredPhotos = photos.filter { photo in
            // 日付範囲を確認
            if let dateRange = options.dateRange {
                guard dateRange.contains(photo.captureDate) else { return false }
            }
            
            // カテゴリーを確認
            if let categories = options.categories {
                guard categories.contains(photo.categoryId) else { return false }
            }
            
            return true
        }
        
        // カテゴリーディレクトリを作成
        var categoryDirs: [String: URL] = [:]
        for photo in filteredPhotos {
            if categoryDirs[photo.categoryId] == nil {
                let categoryDir = directory.appendingPathComponent(photo.categoryId)
                try FileManager.default.createDirectory(at: categoryDir, withIntermediateDirectories: true)
                categoryDirs[photo.categoryId] = categoryDir
            }
        }
        
        // 写真をエクスポート
        for (index, photo) in filteredPhotos.enumerated() {
            guard let categoryDir = categoryDirs[photo.categoryId] else { continue }
            
            // 画像ファイルをコピー
            if let sourceImagePath = photo.fileURL {
                let destImagePath = categoryDir.appendingPathComponent(photo.fileName)
                
                if FileManager.default.fileExists(atPath: sourceImagePath.path) {
                    try FileManager.default.copyItem(at: sourceImagePath, to: destImagePath)
                }
            }
            
            // メタデータをJSONとして保存
            let metadataFileName = photo.id.uuidString + ".json"
            let destMetadataPath = categoryDir.appendingPathComponent(metadataFileName)
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let metadataData = try encoder.encode(photo)
            try metadataData.write(to: destMetadataPath)
            
            exportedPhotos.append(photo)
            progress(Float(index + 1) / Float(filteredPhotos.count))
        }
        
        return exportedPhotos
    }
    
    private func exportVideos(
        to directory: URL,
        options: ExportOptions,
        progress: @escaping (Float) -> Void
    ) throws -> [Video] {
        var exportedVideos: [Video] = []
        VideoStorageService.shared.initialize()
        let videos = VideoStorageService.shared.videos
        
        // 日付範囲に基づいて動画をフィルター
        let filteredVideos = videos.filter { video in
            if let dateRange = options.dateRange {
                return dateRange.overlaps(video.startDate...video.endDate)
            }
            return true
        }
        
        // 動画をエクスポート
        for (index, video) in filteredVideos.enumerated() {
            // 動画ファイルをコピー
            let sourceVideoPath = video.fileURL
            let destVideoPath = directory.appendingPathComponent(video.fileName)
            
            if FileManager.default.fileExists(atPath: sourceVideoPath.path) {
                try FileManager.default.copyItem(at: sourceVideoPath, to: destVideoPath)
            }
            
            // メタデータをJSONとして保存
            let metadataFileName = video.id.uuidString + ".json"
            let destMetadataPath = directory.appendingPathComponent(metadataFileName)
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let metadataData = try encoder.encode(video)
            try metadataData.write(to: destMetadataPath)
            
            // サムネイルがあればコピー
            if let thumbnailURL = video.thumbnailURL,
               FileManager.default.fileExists(atPath: thumbnailURL.path) {
                let destThumbnailPath = directory.appendingPathComponent(thumbnailURL.lastPathComponent)
                try FileManager.default.copyItem(at: thumbnailURL, to: destThumbnailPath)
            }
            
            exportedVideos.append(video)
            progress(Float(index + 1) / Float(filteredVideos.count))
        }
        
        return exportedVideos
    }
    
    private func filterWeightEntries(_ entries: [WeightEntry], options: ExportOptions) -> [WeightEntry] {
        guard let dateRange = options.dateRange else { return entries }
        return entries.filter { dateRange.contains($0.date) }
    }
    
    private func filterNotes(_ notes: [DailyNote], options: ExportOptions) -> [DailyNote] {
        guard let dateRange = options.dateRange else { return notes }
        return notes.filter { dateRange.contains($0.date) }
    }
    
    private func createManifest(
        photos: [Photo],
        videos: [Video],
        categories: [PhotoCategory],
        options: ExportOptions
    ) -> ExportManifest {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        
        let deviceInfo = ExportManifest.DeviceInfo(
            model: UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion,
            locale: Locale.current.identifier
        )
        
        var dateRange: ExportManifest.DateRange?
        if let range = options.dateRange {
            dateRange = ExportManifest.DateRange(start: range.lowerBound, end: range.upperBound)
        }
        
        let dataInfo = ExportManifest.DataInfo(
            photoCount: photos.count,
            videoCount: videos.count,
            categoryCount: categories.count,
            weightEntryCount: 0, // Will be updated after weight export
            noteCount: 0, // Will be updated after note export
            dateRange: dateRange
        )
        
        return ExportManifest(
            version: "1.0",
            exportDate: Date(),
            appVersion: appVersion,
            deviceInfo: deviceInfo,
            dataInfo: dataInfo
        )
    }
    
    private func importCategories(_ categories: [PhotoCategory], options: ImportOptions) throws -> Int {
        var imported = 0
        
        print("[ImportExport] Importing \(categories.count) categories")
        
        for category in categories {
            autoreleasepool {
                let existing = CategoryStorageService.shared.getCategoryById(category.id)
                print("[ImportExport] Category \(category.id) exists: \(existing != nil)")
                
                switch options.mergeStrategy {
                case .skip:
                    if existing == nil {
                        print("[ImportExport] Adding new category: \(category.name)")
                        _ = CategoryStorageService.shared.addCategory(category)
                        imported += 1
                    } else {
                        print("[ImportExport] Skipping existing category: \(category.name)")
                    }
                case .replace:
                    if existing != nil {
                        print("[ImportExport] Updating existing category: \(category.name)")
                        CategoryStorageService.shared.updateCategory(category)
                    } else {
                        print("[ImportExport] Adding new category: \(category.name)")
                        _ = CategoryStorageService.shared.addCategory(category)
                    }
                    imported += 1
                }
            }
        }
        
        print("[ImportExport] Total categories imported: \(imported)")
        return imported
    }
    
    private func importPhotos(
        from directory: URL,
        options: ImportOptions,
        progress: @escaping (Float) -> Void
    ) throws -> Int {
        var imported = 0
        
        print("[ImportExport] Importing photos from: \(directory.path)")
        
        // Check if directory exists
        guard FileManager.default.fileExists(atPath: directory.path) else {
            print("[ImportExport] Photos directory does not exist")
            return 0
        }
        
        let categoryDirs = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey]
        )
        
        print("[ImportExport] Found \(categoryDirs.count) category directories")
        for dir in categoryDirs {
            print("[ImportExport] Category dir: \(dir.lastPathComponent)")
        }
        
        let totalPhotos = categoryDirs.flatMap { categoryDir -> [URL] in
            (try? FileManager.default.contentsOfDirectory(
                at: categoryDir,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "json" }) ?? []
        }.count
        
        print("[ImportExport] Total photo metadata files: \(totalPhotos)")
        
        var processedPhotos = 0
        
        for categoryDir in categoryDirs {
            let categoryId = categoryDir.lastPathComponent
            print("[ImportExport] Processing category: \(categoryId)")
            let photoFiles = try FileManager.default.contentsOfDirectory(
                at: categoryDir,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "json" }
            
            print("[ImportExport] Found \(photoFiles.count) photo metadata files in category \(categoryId)")
            
            for metadataFile in photoFiles {
                // Use autoreleasepool for memory management
                autoreleasepool {
                            // Read metadata file safely
                            print("[ImportExport] Reading metadata file: \(metadataFile.lastPathComponent)")
                            guard let photo = try? self.safelyDecodeJSON(Photo.self, from: metadataFile) else {
                                print("[ImportExport] Failed to decode photo metadata from: \(metadataFile.lastPathComponent)")
                                processedPhotos += 1
                                progress(Float(processedPhotos) / Float(totalPhotos))
                                return  // This returns from autoreleasepool, not the method
                            }
                            print("[ImportExport] Successfully decoded photo: \(photo.id)")
                            
                            // Check if photo already exists
                            let existing = PhotoStorageService.shared.photos.first { $0.id == photo.id }
                            print("[ImportExport] Photo \(photo.id) exists: \(existing != nil)")
                            
                            var shouldImport = false
                            switch options.mergeStrategy {
                            case .skip:
                                shouldImport = (existing == nil)
                                print("[ImportExport] Merge strategy: skip, shouldImport: \(shouldImport)")
                            case .replace:
                                shouldImport = true
                                print("[ImportExport] Merge strategy: replace, shouldImport: \(shouldImport)")
                            }
                            
                            if shouldImport {
                                print("[ImportExport] Importing photo \(photo.id)")
                                // Copy image file
                                let sourceImagePath = categoryDir.appendingPathComponent(photo.fileName)
                                print("[ImportExport] Looking for image file: \(sourceImagePath.path)")
                                
                                // Load image safely with proper error handling
                                if FileManager.default.fileExists(atPath: sourceImagePath.path) {
                                    do {
                                        // Check file size
                                        let attrs = try FileManager.default.attributesOfItem(atPath: sourceImagePath.path)
                                        let fileSize = attrs[.size] as? Int64 ?? 0
                                        if fileSize > 0 && fileSize < 50_000_000 { // Max 50MB per image
                                            // メモリマッピングで画像データを読み込み
                                            let imageData = try Data(contentsOf: sourceImagePath, options: [.mappedIfSafe])
                                            
                                            // 画像を作成
                                            if let image = UIImage(data: imageData) {
                                                print("[ImportExport] Created UIImage successfully")
                                                do {
                                                    let savedPhoto = try PhotoStorageService.shared.savePhoto(
                                                        image,
                                                        captureDate: photo.captureDate,
                                                        categoryId: photo.categoryId,
                                                        isFaceBlurred: photo.isFaceBlurred,
                                                        weight: photo.weight,
                                                        bodyFatPercentage: photo.bodyFatPercentage
                                                    )
                                                    imported += 1
                                                    print("[ImportExport] Successfully saved photo: \(savedPhoto.id)")
                                                } catch {
                                                    print("[ImportExport] Failed to save photo: \(error)")
                                                }
                                            } else {
                                                print("[ImportExport] Failed to create UIImage from data")
                                            }
                                        } else {
                                            print("Image too large or invalid size: \(fileSize) bytes")
                                        }
                                    } catch {
                                        print("Error loading image: \(error)")
                                    }
                                } else {
                                    print("[ImportExport] Image file not found: \(sourceImagePath.path)")
                                }
                            }
                }
                
                processedPhotos += 1
                progress(Float(processedPhotos) / Float(totalPhotos))
            }
        }
        
        print("[ImportExport] Total photos imported: \(imported)")
        return imported
    }
    
    private func importVideos(
        from directory: URL,
        options: ImportOptions,
        progress: @escaping (Float) -> Void
    ) async throws -> Int {
        var imported = 0
        let videoFiles = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }
        
        print("[ImportExport] Found \(videoFiles.count) video metadata files to import")
        
        for (index, metadataFile) in videoFiles.enumerated() {
            // Process video import
            do {
                let metadataData = try Data(contentsOf: metadataFile)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let video = try decoder.decode(Video.self, from: metadataData)
                
                // 動画が既に存在するか確認
                VideoStorageService.shared.initialize()
                let existing = VideoStorageService.shared.videos.first { $0.id == video.id }
                print("[ImportExport] Video \(video.id) exists: \(existing != nil)")
            
            var shouldImport = false
            switch options.mergeStrategy {
            case .skip:
                shouldImport = (existing == nil)
                print("[ImportExport] Merge strategy: skip, shouldImport: \(shouldImport)")
            case .replace:
                shouldImport = true
                if existing != nil {
                    print("[ImportExport] Deleting existing video")
                    try VideoStorageService.shared.deleteVideo(existing!)
                }
                print("[ImportExport] Merge strategy: replace, shouldImport: \(shouldImport)")
            }
            
            if shouldImport {
                print("[ImportExport] Importing video \(video.id)")
                // Copy video file
                let sourceVideoPath = directory.appendingPathComponent(video.fileName)
                print("[ImportExport] Looking for video file: \(sourceVideoPath.path)")
                
                if FileManager.default.fileExists(atPath: sourceVideoPath.path) {
                    _ = try await VideoStorageService.shared.saveVideo(
                        sourceVideoPath,
                        startDate: video.startDate,
                        endDate: video.endDate,
                        frameCount: video.frameCount
                    )
                    imported += 1
                    print("[ImportExport] Successfully imported video: \(video.fileName)")
                } else {
                    print("[ImportExport] Video file not found: \(sourceVideoPath.path)")
                }
                } else {
                    print("[ImportExport] Skipping video import (shouldImport = false)")
                }
            } catch {
                // Log error but continue processing other videos
                print("[ImportExport] Error importing video from \(metadataFile.lastPathComponent): \(error)")
                print("[ImportExport] Error details: \(error.localizedDescription)")
            }
            
            progress(Float(index + 1) / Float(videoFiles.count))
        }
        
        return imported
    }
    
    private func importWeightEntries(_ entries: [WeightEntry], options: ImportOptions) async throws -> Int {
        var imported = 0
        
        for entry in entries {
            let existing = try await WeightStorageService.shared.getEntry(for: entry.date)
            
            var shouldImport = false
            switch options.mergeStrategy {
            case .skip:
                shouldImport = (existing == nil)
            case .replace:
                shouldImport = true
            }
            
            if shouldImport {
                try await WeightStorageService.shared.saveEntry(entry)
                imported += 1
            }
        }
        
        return imported
    }
    
    private func importNotes(_ notes: [DailyNote], options: ImportOptions) async throws -> Int {
        var imported = 0
        
        for note in notes {
            let existing = await DailyNoteStorageService.shared.getNote(for: note.date)
            
            var shouldImport = false
            switch options.mergeStrategy {
            case .skip:
                shouldImport = (existing == nil)
            case .replace:
                shouldImport = true
            }
            
            if shouldImport {
                try await DailyNoteStorageService.shared.saveNote(for: note.date, content: note.content)
                imported += 1
            }
        }
        
        return imported
    }
    
    struct ImportSummary {
        var photosImported: Int = 0
        var videosImported: Int = 0
        var categoriesImported: Int = 0
        var weightEntriesImported: Int = 0
        var notesImported: Int = 0
        var settingsImported: Bool = false
        
        var totalItemsImported: Int {
            photosImported + videosImported + categoriesImported + weightEntriesImported + notesImported
        }
    }
}
