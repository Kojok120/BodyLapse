import Foundation
import UIKit

class ImportExportService {
    static let shared = ImportExportService()
    private static let safePathComponentCharacters = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"
    )
    
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
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            Task {
                await self.performExport(options: options, progress: progress, completion: completion)
            }
        }
    }
    
    private func performExport(
        options: ExportOptions,
        progress: @escaping (Float) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) async {
        do {
            let photosToExport = options.includePhotos ? filterPhotos(options: options) : []
            let videosToExport = options.includeVideos ? filterVideos(options: options) : []
            let categories = filterCategories(CategoryStorageService.shared.getActiveCategories(), options: options)

            var totalSteps = Float(photosToExport.count + videosToExport.count + 5)
            if totalSteps <= 0 {
                totalSteps = 1
            }

            var currentStep: Float = 0
            var archiveEntries: [SimpleZipArchive.ArchiveEntry] = []

            // 写真をエクスポート
            let exportedPhotos: [Photo]
            if options.includePhotos {
                let photoResult = try self.exportPhotos(
                    photosToExport,
                    progress: { photoProgress in
                        let stepProgress = currentStep + (photoProgress * Float(max(photosToExport.count, 1)))
                        progress(stepProgress / totalSteps)
                    }
                )
                archiveEntries.append(contentsOf: photoResult.entries)
                exportedPhotos = photoResult.photos
                currentStep += Float(photosToExport.count)
            } else {
                exportedPhotos = []
            }

            // 動画をエクスポート
            let exportedVideos: [Video]
            if options.includeVideos {
                let videoResult = try self.exportVideos(
                    videosToExport,
                    progress: { videoProgress in
                        let stepProgress = currentStep + (videoProgress * Float(max(videosToExport.count, 1)))
                        progress(stepProgress / totalSteps)
                    }
                )
                archiveEntries.append(contentsOf: videoResult.entries)
                exportedVideos = videoResult.videos
                currentStep += Float(videosToExport.count)
            } else {
                exportedVideos = []
            }

            // カテゴリーをエクスポート
            let categoriesData = try encodeJSON(categories)
            archiveEntries.append(
                SimpleZipArchive.ArchiveEntry(
                    path: "data/categories.json",
                    source: .data(categoriesData)
                )
            )

            currentStep += 1
            progress(currentStep / totalSteps)

            // 体重データをエクスポート
            var filteredWeightEntries: [WeightEntry] = []
            if options.includeWeightData {
                let weightEntries = try await WeightStorageService.shared.loadEntries()
                filteredWeightEntries = self.filterWeightEntries(weightEntries, options: options)
                let weightData = try encodeJSON(filteredWeightEntries)
                archiveEntries.append(
                    SimpleZipArchive.ArchiveEntry(
                        path: "data/weight_data.json",
                        source: .data(weightData)
                    )
                )
            }

            currentStep += 1
            progress(currentStep / totalSteps)

            // ノートをエクスポート
            var filteredNotes: [DailyNote] = []
            if options.includeNotes {
                let notes = await DailyNoteStorageService.shared.getAllNotes()
                filteredNotes = self.filterNotes(notes, options: options)
                let notesData = try encodeJSON(filteredNotes)
                archiveEntries.append(
                    SimpleZipArchive.ArchiveEntry(
                        path: "data/notes.json",
                        source: .data(notesData)
                    )
                )
            }

            currentStep += 1
            progress(currentStep / totalSteps)

            // リクエストに応じて設定をエクスポート
            if options.includeSettings {
                let settings = await MainActor.run {
                    UserSettingsManager.shared.settings
                }
                let settingsData = try encodeJSON(settings)
                archiveEntries.append(
                    SimpleZipArchive.ArchiveEntry(
                        path: "data/settings.json",
                        source: .data(settingsData)
                    )
                )
            }

            currentStep += 1
            progress(currentStep / totalSteps)

            // マニフェストを作成
            let manifest = self.createManifest(
                photos: exportedPhotos,
                videos: exportedVideos,
                categories: categories,
                weightEntries: filteredWeightEntries,
                notes: filteredNotes,
                options: options
            )
            let manifestData = try encodeJSON(manifest)
            archiveEntries.append(
                SimpleZipArchive.ArchiveEntry(
                    path: "manifest.json",
                    source: .data(manifestData)
                )
            )

            currentStep += 1
            progress(currentStep / totalSteps)

            // .bodylapseファイルを直接生成
            let zipPath = FileManager.default.temporaryDirectory
                .appendingPathComponent("BodyLapse_Export_\(UUID().uuidString).bodylapse")

            guard SimpleZipArchive.createArchive(atPath: zipPath.path, entries: archiveEntries) else {
                throw ImportExportError.zipOperationFailed
            }

            progress(1)

            DispatchQueue.main.async {
                completion(.success(zipPath))
            }
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - インポート
    
    /// 以前のインポートで残った一時ディレクトリ（BodyLapseImport_*）を掃除する。
    /// アプリ強制終了などで defer が走らなかった場合のディスクリークを回収する。
    func cleanupLeftoverImportTempDirectories() {
        let tempDir = FileManager.default.temporaryDirectory
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: nil
        ) else { return }

        for url in contents where url.lastPathComponent.hasPrefix("BodyLapseImport_") {
            do {
                try FileManager.default.removeItem(at: url)
                print("[ImportExport] Cleaned up leftover temp dir: \(url.lastPathComponent)")
            } catch {
                print("[ImportExport] Failed to clean up leftover temp dir \(url.lastPathComponent): \(error)")
            }
        }
    }

    func importData(
        from url: URL,
        options: ImportOptions,
        progress: @escaping (Float) -> Void,
        completion: @escaping (Result<ImportSummary, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            Task {
                await self.performImport(from: url, options: options, progress: progress, completion: completion)
            }
        }
    }
    
    private func performImport(
        from url: URL,
        options: ImportOptions,
        progress: @escaping (Float) -> Void,
        completion: @escaping (Result<ImportSummary, Error>) -> Void
    ) async {
        print("[ImportExport] Starting import from: \(url.path)")

        // 前回のインポートで残った一時ディレクトリを掃除（ディスクリーク防止）
        cleanupLeftoverImportTempDirectories()

        do {
                // 展開用の一時ディレクトリを作成
                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("BodyLapseImport_\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                defer {
                    do {
                        try FileManager.default.removeItem(at: tempDir)
                    } catch {
                        // 削除失敗を握り潰さず記録（ディスクリーク検知のため）
                        print("[ImportExport] Failed to remove temp dir \(tempDir.lastPathComponent): \(error)")
                    }
                }
                
                // 展開前にファイルサイズを検証
                print("[ImportExport] Validating file size...")
                let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
                print("[ImportExport] File size: \(fileSize) bytes")
                guard fileSize > 0 && fileSize < 2_000_000_000 else { // Max 2GB（動画を含むバックアップを許容）
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
                    let sanitizedCategories = categories.compactMap { self.sanitizedImportedCategory(from: $0) }
                    summary.categoriesImported = try self.importCategories(sanitizedCategories, options: options)
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
                        let photoResult = try self.importPhotos(
                            from: photosDir,
                            options: options,
                            progress: { photoProgress in
                                let stepProgress = currentStep + (photoProgress * Float(manifest.dataInfo.photoCount))
                                progress(stepProgress / totalSteps)
                            }
                        )
                        summary.photosImported = photoResult.imported
                        summary.photosFailed = photoResult.failed
                        print("[ImportExport] Photos imported: \(summary.photosImported), failed: \(summary.photosFailed)")
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
        
        // まずISO8601でデコードを試行
        do {
            return try makeJSONDecoder(dateStrategy: .iso8601).decode(type, from: data)
        } catch {
            // ISO8601が失敗した場合、タイムスタンプで試行（後方互換性のため）
            print("ISO8601 decode failed, trying timestamp strategy: \(error)")
            do {
                return try makeJSONDecoder(dateStrategy: .secondsSince1970).decode(type, from: data)
            } catch {
                print("JSON decode error for \(type): \(error)")
                throw ImportExportError.invalidFormat
            }
        }
    }

    private func makeJSONEncoder(prettyPrinted: Bool = false) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        return encoder
    }

    private func makeJSONDecoder(dateStrategy: JSONDecoder.DateDecodingStrategy) -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = dateStrategy
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        return decoder
    }

    private func encodeJSON<T: Encodable>(_ value: T, prettyPrinted: Bool = false) throws -> Data {
        try makeJSONEncoder(prettyPrinted: prettyPrinted).encode(value)
    }

    private func sanitizedPathComponent(_ value: String, maxLength: Int = 128) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxLength else { return nil }
        guard trimmed != ".", trimmed != ".." else { return nil }
        guard !trimmed.contains("/"), !trimmed.contains("\\") else { return nil }
        guard trimmed.unicodeScalars.allSatisfy({ Self.safePathComponentCharacters.contains($0) }) else {
            return nil
        }
        return trimmed
    }

    private func safeChildURL(for fileName: String, under directory: URL) -> URL? {
        guard let safeFileName = sanitizedPathComponent(fileName, maxLength: 255) else { return nil }

        let root = directory.standardizedFileURL.resolvingSymlinksInPath()
        let candidate = root
            .appendingPathComponent(safeFileName)
            .standardizedFileURL
            .resolvingSymlinksInPath()

        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard candidate.path.hasPrefix(rootPath) else {
            return nil
        }
        return candidate
    }

    private func sanitizedImportedCategory(from category: PhotoCategory) -> PhotoCategory? {
        guard let safeCategoryId = sanitizedPathComponent(category.id, maxLength: 64) else {
            return nil
        }
        let trimmedName = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = String((trimmedName.isEmpty ? safeCategoryId : trimmedName).prefix(50))

        return PhotoCategory(
            id: safeCategoryId,
            name: safeName,
            order: max(0, category.order),
            isDefault: category.isDefault,
            guideline: category.guideline,
            createdDate: category.createdDate,
            isActive: category.isActive
        )
    }

    private func filterPhotos(options: ExportOptions) -> [Photo] {
        PhotoStorageService.shared.photos.filter { photo in
            if let dateRange = options.dateRange,
               !dateRange.contains(photo.captureDate) {
                return false
            }

            if let categories = options.categories,
               !categories.contains(photo.categoryId) {
                return false
            }

            return true
        }
    }

    private func filterVideos(options: ExportOptions) -> [Video] {
        VideoStorageService.shared.initialize()
        return VideoStorageService.shared.videos.filter { video in
            guard let dateRange = options.dateRange else { return true }
            return dateRange.overlaps(video.startDate...video.endDate)
        }
    }

    private func filterCategories(_ categories: [PhotoCategory], options: ExportOptions) -> [PhotoCategory] {
        guard let selectedCategories = options.categories else {
            return categories
        }
        return categories.filter { selectedCategories.contains($0.id) }
    }
    
    private func exportPhotos(
        _ photos: [Photo],
        progress: @escaping (Float) -> Void
    ) throws -> (entries: [SimpleZipArchive.ArchiveEntry], photos: [Photo]) {
        let totalPhotos = Float(max(photos.count, 1))
        var archiveEntries: [SimpleZipArchive.ArchiveEntry] = []
        var exportedPhotos: [Photo] = []
        
        // 写真をエクスポート
        for (index, photo) in photos.enumerated() {
            defer {
                progress(Float(index + 1) / totalPhotos)
            }

            guard let categoryId = sanitizedPathComponent(photo.categoryId, maxLength: 64),
                  let imageFileName = sanitizedPathComponent(photo.fileName, maxLength: 255),
                  let sourceImagePath = photo.fileURL,
                  FileManager.default.fileExists(atPath: sourceImagePath.path) else {
                continue
            }

            let basePath = "photos/\(categoryId)"
            let metadataFileName = photo.id.uuidString + ".json"
            let metadataData = try encodeJSON(photo, prettyPrinted: true)

            archiveEntries.append(
                SimpleZipArchive.ArchiveEntry(
                    path: "\(basePath)/\(imageFileName)",
                    source: .file(sourceImagePath)
                )
            )
            archiveEntries.append(
                SimpleZipArchive.ArchiveEntry(
                    path: "\(basePath)/\(metadataFileName)",
                    source: .data(metadataData)
                )
            )
            exportedPhotos.append(photo)
        }
        
        return (archiveEntries, exportedPhotos)
    }
    
    private func exportVideos(
        _ videos: [Video],
        progress: @escaping (Float) -> Void
    ) throws -> (entries: [SimpleZipArchive.ArchiveEntry], videos: [Video]) {
        let totalVideos = Float(max(videos.count, 1))
        var archiveEntries: [SimpleZipArchive.ArchiveEntry] = []
        var exportedVideos: [Video] = []
        
        // 動画をエクスポート
        for (index, video) in videos.enumerated() {
            defer {
                progress(Float(index + 1) / totalVideos)
            }

            guard let videoFileName = sanitizedPathComponent(video.fileName, maxLength: 255) else {
                continue
            }

            let sourceVideoPath = video.fileURL
            guard FileManager.default.fileExists(atPath: sourceVideoPath.path) else {
                continue
            }

            // メタデータをJSONとして保存
            let metadataFileName = video.id.uuidString + ".json"
            let metadataData = try encodeJSON(video, prettyPrinted: true)

            archiveEntries.append(
                SimpleZipArchive.ArchiveEntry(
                    path: "videos/\(videoFileName)",
                    source: .file(sourceVideoPath)
                )
            )
            archiveEntries.append(
                SimpleZipArchive.ArchiveEntry(
                    path: "videos/\(metadataFileName)",
                    source: .data(metadataData)
                )
            )

            // サムネイルがあればコピー
            if let thumbnailURL = video.thumbnailURL,
               let thumbnailFileName = sanitizedPathComponent(thumbnailURL.lastPathComponent, maxLength: 255),
               FileManager.default.fileExists(atPath: thumbnailURL.path) {
                archiveEntries.append(
                    SimpleZipArchive.ArchiveEntry(
                        path: "videos/\(thumbnailFileName)",
                        source: .file(thumbnailURL)
                    )
                )
            }

            exportedVideos.append(video)
        }
        
        return (archiveEntries, exportedVideos)
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
        weightEntries: [WeightEntry],
        notes: [DailyNote],
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
            weightEntryCount: weightEntries.count,
            noteCount: notes.count,
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
                        if CategoryStorageService.shared.addCategory(category) {
                            imported += 1
                        } else {
                            print("[ImportExport] Failed to add category (limit reached?): \(category.name)")
                        }
                    } else {
                        print("[ImportExport] Skipping existing category: \(category.name)")
                    }
                case .replace:
                    if existing != nil {
                        print("[ImportExport] Updating existing category: \(category.name)")
                        CategoryStorageService.shared.updateCategory(category)
                        imported += 1
                    } else {
                        print("[ImportExport] Adding new category: \(category.name)")
                        if CategoryStorageService.shared.addCategory(category) {
                            imported += 1
                        } else {
                            print("[ImportExport] Failed to add category (limit reached?): \(category.name)")
                        }
                    }
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
    ) throws -> (imported: Int, failed: Int) {
        var imported = 0
        var failed = 0

        print("[ImportExport] Importing photos from: \(directory.path)")

        // Check if directory exists
        guard FileManager.default.fileExists(atPath: directory.path) else {
            print("[ImportExport] Photos directory does not exist")
            return (0, 0)
        }
        
        let categoryDirs = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey]
        ).filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
        
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
        let totalPhotosFloat = Float(max(totalPhotos, 1))
        
        for categoryDir in categoryDirs {
            guard let categoryId = sanitizedPathComponent(categoryDir.lastPathComponent, maxLength: 64) else {
                print("[ImportExport] Invalid category directory name: \(categoryDir.lastPathComponent)")
                continue
            }
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
                                failed += 1
                                return  // This returns from autoreleasepool, not the method
                            }
                            print("[ImportExport] Successfully decoded photo: \(photo.id)")

                            guard let imageFileName = self.sanitizedPathComponent(photo.fileName, maxLength: 255) else {
                                print("[ImportExport] Invalid image file name in metadata: \(photo.fileName)")
                                failed += 1
                                return
                            }

                            let metadataCategoryId = self.sanitizedPathComponent(photo.categoryId, maxLength: 64)
                            let targetCategoryId = metadataCategoryId ?? categoryId
                            let finalCategoryId: String
                            if CategoryStorageService.shared.getCategoryById(targetCategoryId) != nil {
                                finalCategoryId = targetCategoryId
                            } else {
                                finalCategoryId = categoryId
                            }

                            // アプリのデータモデルは「1日1カテゴリ1枚」なので、
                            // 既存判定はIDではなく撮影日（同日）+カテゴリで行う
                            let existing = PhotoStorageService.shared.getPhotoForDate(photo.captureDate, categoryId: finalCategoryId)
                            print("[ImportExport] Photo for \(photo.captureDate) in \(finalCategoryId) exists: \(existing != nil)")

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
                                guard let sourceImagePath = self.safeChildURL(for: imageFileName, under: categoryDir) else {
                                    print("[ImportExport] Unsafe image path in metadata: \(photo.fileName)")
                                    failed += 1
                                    return
                                }
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
                                                    let savedPhoto: Photo
                                                    if existing != nil {
                                                        // 置換: 同日・同カテゴリの既存写真を削除してから保存
                                                        savedPhoto = try PhotoStorageService.shared.replacePhoto(
                                                            for: photo.captureDate,
                                                            categoryId: finalCategoryId,
                                                            with: image,
                                                            isFaceBlurred: photo.isFaceBlurred,
                                                            bodyDetectionConfidence: photo.bodyDetectionConfidence,
                                                            weight: photo.weight,
                                                            bodyFatPercentage: photo.bodyFatPercentage
                                                        )
                                                    } else {
                                                        savedPhoto = try PhotoStorageService.shared.savePhoto(
                                                            image,
                                                            captureDate: photo.captureDate,
                                                            categoryId: finalCategoryId,
                                                            isFaceBlurred: photo.isFaceBlurred,
                                                            bodyDetectionConfidence: photo.bodyDetectionConfidence,
                                                            weight: photo.weight,
                                                            bodyFatPercentage: photo.bodyFatPercentage
                                                        )
                                                    }
                                                    imported += 1
                                                    print("[ImportExport] Successfully saved photo: \(savedPhoto.id)")
                                                } catch {
                                                    print("[ImportExport] Failed to save photo: \(error)")
                                                    failed += 1
                                                }
                                            } else {
                                                print("[ImportExport] Failed to create UIImage from data")
                                                failed += 1
                                            }
                                        } else {
                                            print("Image too large or invalid size: \(fileSize) bytes")
                                            failed += 1
                                        }
                                    } catch {
                                        print("Error loading image: \(error)")
                                        failed += 1
                                    }
                                } else {
                                    print("[ImportExport] Image file not found: \(sourceImagePath.path)")
                                    failed += 1
                                }
                            }
                }
                
                processedPhotos += 1
                progress(Float(processedPhotos) / totalPhotosFloat)
            }
        }
        
        print("[ImportExport] Total photos imported: \(imported), failed: \(failed)")
        return (imported, failed)
    }
    
    private func importVideos(
        from directory: URL,
        options: ImportOptions,
        progress: @escaping (Float) -> Void
    ) async throws -> Int {
        var imported = 0
        guard FileManager.default.fileExists(atPath: directory.path) else {
            print("[ImportExport] Videos directory does not exist")
            return 0
        }

        let videoFiles = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }
        
        print("[ImportExport] Found \(videoFiles.count) video metadata files to import")
        let totalVideosFloat = Float(max(videoFiles.count, 1))
        
        for (index, metadataFile) in videoFiles.enumerated() {
            // Process video import
            do {
                let video = try safelyDecodeJSON(Video.self, from: metadataFile)
                guard let videoFileName = sanitizedPathComponent(video.fileName, maxLength: 255) else {
                    print("[ImportExport] Invalid video file name in metadata: \(video.fileName)")
                    progress(Float(index + 1) / totalVideosFloat)
                    continue
                }
                
                // 動画が既に存在するか確認
                // 保存時にIDが再発行されるため、ID一致に加えて内容（期間・フレーム数）でも判定する
                VideoStorageService.shared.initialize()
                let existing = VideoStorageService.shared.videos.first {
                    $0.id == video.id ||
                    ($0.startDate == video.startDate &&
                     $0.endDate == video.endDate &&
                     $0.frameCount == video.frameCount)
                }
                print("[ImportExport] Video \(video.id) exists: \(existing != nil)")
            
            var shouldImport = false
            switch options.mergeStrategy {
            case .skip:
                shouldImport = (existing == nil)
                print("[ImportExport] Merge strategy: skip, shouldImport: \(shouldImport)")
            case .replace:
                shouldImport = true
                if let existing {
                    print("[ImportExport] Deleting existing video")
                    try VideoStorageService.shared.deleteVideo(existing)
                }
                print("[ImportExport] Merge strategy: replace, shouldImport: \(shouldImport)")
            }
            
            if shouldImport {
                print("[ImportExport] Importing video \(video.id)")
                // Copy video file
                guard let sourceVideoPath = safeChildURL(for: videoFileName, under: directory) else {
                    print("[ImportExport] Unsafe video path in metadata: \(video.fileName)")
                    progress(Float(index + 1) / totalVideosFloat)
                    continue
                }
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
            
            progress(Float(index + 1) / totalVideosFloat)
        }
        
        return imported
    }
    
    private func importWeightEntries(_ entries: [WeightEntry], options: ImportOptions) async throws -> Int {
        let strategy: WeightStorageService.MergeStrategy = {
            switch options.mergeStrategy {
            case .skip:
                return .skipExisting
            case .replace:
                return .replaceExisting
            }
        }()

        return try await WeightStorageService.shared.mergeEntries(entries, strategy: strategy)
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
        var photosFailed: Int = 0
        var videosImported: Int = 0
        var categoriesImported: Int = 0
        var weightEntriesImported: Int = 0
        var notesImported: Int = 0
        var settingsImported: Bool = false

        var totalItemsImported: Int {
            photosImported + videosImported + categoriesImported + weightEntriesImported + notesImported
        }

        /// 読み込めずスキップされた項目があるか
        var hasFailures: Bool {
            photosFailed > 0
        }
    }
}
