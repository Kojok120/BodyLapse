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
                return "エクスポート失敗: \(reason)"
            case .importFailed(let reason):
                return "インポート失敗: \(reason)"
            case .invalidFormat:
                return "無効なファイル形式です"
            case .noDataToExport:
                return "エクスポートするデータがありません"
            case .fileNotFound:
                return "ファイルが見つかりません"
            case .zipOperationFailed:
                return "ZIP操作に失敗しました"
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
        
        enum MergeStrategy {
            case skip          // Skip existing data
            case replace       // Replace existing data
            case keepBoth      // Keep both (rename new)
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
    
    // MARK: - Export
    
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
                // Create temporary directory
                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("BodyLapseExport_\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                
                var totalSteps: Float = 0
                var currentStep: Float = 0
                
                // Calculate total steps
                if options.includePhotos {
                    totalSteps += Float(PhotoStorageService.shared.photos.count)
                }
                if options.includeVideos {
                    totalSteps += Float(VideoStorageService.shared.videos.count)
                }
                totalSteps += 5 // For other operations
                
                // Create folder structure
                let photosDir = tempDir.appendingPathComponent("photos")
                let videosDir = tempDir.appendingPathComponent("videos")
                let dataDir = tempDir.appendingPathComponent("data")
                
                try FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: videosDir, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
                
                currentStep += 1
                progress(currentStep / totalSteps)
                
                // Export photos
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
                
                // Export videos
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
                
                // Export categories
                let categories = CategoryStorageService.shared.getActiveCategories()
                let categoriesData = try JSONEncoder().encode(categories)
                try categoriesData.write(to: dataDir.appendingPathComponent("categories.json"))
                
                currentStep += 1
                progress(currentStep / totalSteps)
                
                // Export weight data
                if options.includeWeightData {
                    let weightEntries = try await WeightStorageService.shared.loadEntries()
                    let filteredEntries = self.filterWeightEntries(weightEntries, options: options)
                    let weightData = try JSONEncoder().encode(filteredEntries)
                    try weightData.write(to: dataDir.appendingPathComponent("weight_data.json"))
                }
                
                currentStep += 1
                progress(currentStep / totalSteps)
                
                // Export notes
                if options.includeNotes {
                    let notes = await DailyNoteStorageService.shared.getAllNotes()
                    let filteredNotes = self.filterNotes(notes, options: options)
                    let notesData = try JSONEncoder().encode(filteredNotes)
                    try notesData.write(to: dataDir.appendingPathComponent("notes.json"))
                }
                
                currentStep += 1
                progress(currentStep / totalSteps)
                
                // Export settings if requested
                if options.includeSettings {
                    let settings = await MainActor.run {
                        UserSettingsManager.shared.settings
                    }
                    let settingsData = try JSONEncoder().encode(settings)
                    try settingsData.write(to: dataDir.appendingPathComponent("settings.json"))
                }
                
                // Create manifest
                let manifest = self.createManifest(
                    photos: exportedPhotos,
                    videos: exportedVideos,
                    categories: categories,
                    options: options
                )
                let manifestData = try JSONEncoder().encode(manifest)
                try manifestData.write(to: tempDir.appendingPathComponent("manifest.json"))
                
                currentStep += 1
                progress(currentStep / totalSteps)
                
                // Create ZIP file
                let zipPath = FileManager.default.temporaryDirectory
                    .appendingPathComponent("BodyLapse_Export_\(Date().timeIntervalSince1970).bodylapse")
                
                let success = SimpleZipArchive.createZipFile(
                    atPath: zipPath.path,
                    withContentsOfDirectory: tempDir.path,
                    keepParentDirectory: false
                )
                
                // Clean up temp directory
                try? FileManager.default.removeItem(at: tempDir)
                
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
    
    // MARK: - Import
    
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
            
            do {
                // Create temporary directory for extraction
                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("BodyLapseImport_\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                
                // Extract ZIP
                guard SimpleZipArchive.unzipFile(
                    atPath: url.path,
                    toDestination: tempDir.path
                ) else {
                    throw ImportExportError.zipOperationFailed
                }
                
                // Read manifest
                let manifestPath = tempDir.appendingPathComponent("manifest.json")
                guard FileManager.default.fileExists(atPath: manifestPath.path) else {
                    throw ImportExportError.invalidFormat
                }
                
                let manifestData = try Data(contentsOf: manifestPath)
                let manifest = try JSONDecoder().decode(ExportManifest.self, from: manifestData)
                
                var summary = ImportSummary()
                var totalSteps: Float = 0
                var currentStep: Float = 0
                
                // Calculate total steps
                if options.importPhotos {
                    totalSteps += Float(manifest.dataInfo.photoCount)
                }
                if options.importVideos {
                    totalSteps += Float(manifest.dataInfo.videoCount)
                }
                totalSteps += 5 // For other operations
                
                // Import categories first
                let categoriesPath = tempDir.appendingPathComponent("data/categories.json")
                if FileManager.default.fileExists(atPath: categoriesPath.path) {
                    let categoriesData = try Data(contentsOf: categoriesPath)
                    let categories = try JSONDecoder().decode([PhotoCategory].self, from: categoriesData)
                    summary.categoriesImported = try self.importCategories(categories, options: options)
                }
                
                currentStep += 1
                progress(currentStep / totalSteps)
                
                // Import photos
                if options.importPhotos {
                    let photosDir = tempDir.appendingPathComponent("photos")
                    summary.photosImported = try self.importPhotos(
                        from: photosDir,
                        options: options,
                        progress: { photoProgress in
                            let stepProgress = currentStep + (photoProgress * Float(manifest.dataInfo.photoCount))
                            progress(stepProgress / totalSteps)
                        }
                    )
                    currentStep += Float(manifest.dataInfo.photoCount)
                }
                
                // Import videos
                if options.importVideos {
                    let videosDir = tempDir.appendingPathComponent("videos")
                    summary.videosImported = try await self.importVideos(
                        from: videosDir,
                        options: options,
                        progress: { videoProgress in
                            let stepProgress = currentStep + (videoProgress * Float(manifest.dataInfo.videoCount))
                            progress(stepProgress / totalSteps)
                        }
                    )
                    currentStep += Float(manifest.dataInfo.videoCount)
                }
                
                // Import weight data
                if options.importWeightData {
                    let weightPath = tempDir.appendingPathComponent("data/weight_data.json")
                    if FileManager.default.fileExists(atPath: weightPath.path) {
                        let weightData = try Data(contentsOf: weightPath)
                        let entries = try JSONDecoder().decode([WeightEntry].self, from: weightData)
                        summary.weightEntriesImported = try await self.importWeightEntries(entries, options: options)
                    }
                }
                
                currentStep += 1
                progress(currentStep / totalSteps)
                
                // Import notes
                if options.importNotes {
                    let notesPath = tempDir.appendingPathComponent("data/notes.json")
                    if FileManager.default.fileExists(atPath: notesPath.path) {
                        let notesData = try Data(contentsOf: notesPath)
                        let notes = try JSONDecoder().decode([DailyNote].self, from: notesData)
                        summary.notesImported = try await self.importNotes(notes, options: options)
                    }
                }
                
                currentStep += 1
                progress(currentStep / totalSteps)
                
                // Import settings if requested
                if options.importSettings {
                    let settingsPath = tempDir.appendingPathComponent("data/settings.json")
                    if FileManager.default.fileExists(atPath: settingsPath.path) {
                        let settingsData = try Data(contentsOf: settingsPath)
                        let settings = try JSONDecoder().decode(UserSettings.self, from: settingsData)
                        await MainActor.run {
                        UserSettingsManager.shared.settings = settings
                    }
                        summary.settingsImported = true
                    }
                }
                
                // Clean up temp directory
                try? FileManager.default.removeItem(at: tempDir)
                
                DispatchQueue.main.async {
                    completion(.success(summary))
                }
                
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func exportPhotos(
        to directory: URL,
        options: ExportOptions,
        progress: @escaping (Float) -> Void
    ) throws -> [Photo] {
        var exportedPhotos: [Photo] = []
        let photos = PhotoStorageService.shared.photos
        
        // Filter photos based on options
        let filteredPhotos = photos.filter { photo in
            // Check date range
            if let dateRange = options.dateRange {
                guard dateRange.contains(photo.captureDate) else { return false }
            }
            
            // Check categories
            if let categories = options.categories {
                guard categories.contains(photo.categoryId) else { return false }
            }
            
            return true
        }
        
        // Create category directories
        var categoryDirs: [String: URL] = [:]
        for photo in filteredPhotos {
            if categoryDirs[photo.categoryId] == nil {
                let categoryDir = directory.appendingPathComponent(photo.categoryId)
                try FileManager.default.createDirectory(at: categoryDir, withIntermediateDirectories: true)
                categoryDirs[photo.categoryId] = categoryDir
            }
        }
        
        // Export photos
        for (index, photo) in filteredPhotos.enumerated() {
            guard let categoryDir = categoryDirs[photo.categoryId] else { continue }
            
            // Copy image file
            if let sourceImagePath = photo.fileURL {
                let destImagePath = categoryDir.appendingPathComponent(photo.fileName)
                
                if FileManager.default.fileExists(atPath: sourceImagePath.path) {
                    try FileManager.default.copyItem(at: sourceImagePath, to: destImagePath)
                }
            }
            
            // Save metadata as JSON
            let metadataFileName = photo.id.uuidString + ".json"
            let destMetadataPath = categoryDir.appendingPathComponent(metadataFileName)
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
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
        
        // Filter videos based on date range
        let filteredVideos = videos.filter { video in
            if let dateRange = options.dateRange {
                return dateRange.overlaps(video.startDate...video.endDate)
            }
            return true
        }
        
        // Export videos
        for (index, video) in filteredVideos.enumerated() {
            // Copy video file
            let sourceVideoPath = video.fileURL
            let destVideoPath = directory.appendingPathComponent(video.fileName)
            
            if FileManager.default.fileExists(atPath: sourceVideoPath.path) {
                try FileManager.default.copyItem(at: sourceVideoPath, to: destVideoPath)
            }
            
            // Save metadata as JSON
            let metadataFileName = video.id.uuidString + ".json"
            let destMetadataPath = directory.appendingPathComponent(metadataFileName)
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let metadataData = try encoder.encode(video)
            try metadataData.write(to: destMetadataPath)
            
            // Copy thumbnail if exists
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
        
        for category in categories {
            let existing = CategoryStorageService.shared.getCategoryById(category.id)
            
            switch options.mergeStrategy {
            case .skip:
                if existing == nil {
                    _ = CategoryStorageService.shared.addCategory(category)
                    imported += 1
                }
            case .replace:
                if existing != nil {
                    CategoryStorageService.shared.updateCategory(category)
                } else {
                    _ = CategoryStorageService.shared.addCategory(category)
                }
                imported += 1
            case .keepBoth:
                if existing != nil {
                    // Create new category with modified name
                    var newCategory = category
                    newCategory.name = "\(category.name) (インポート)"
                    _ = CategoryStorageService.shared.addCategory(newCategory)
                } else {
                    _ = CategoryStorageService.shared.addCategory(category)
                }
                imported += 1
            }
        }
        
        return imported
    }
    
    private func importPhotos(
        from directory: URL,
        options: ImportOptions,
        progress: @escaping (Float) -> Void
    ) throws -> Int {
        var imported = 0
        let categoryDirs = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey]
        )
        
        let totalPhotos = categoryDirs.flatMap { categoryDir -> [URL] in
            (try? FileManager.default.contentsOfDirectory(
                at: categoryDir,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "json" }) ?? []
        }.count
        
        var processedPhotos = 0
        
        for categoryDir in categoryDirs {
            let _ = categoryDir.lastPathComponent
            let photoFiles = try FileManager.default.contentsOfDirectory(
                at: categoryDir,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "json" }
            
            for metadataFile in photoFiles {
                let metadataData = try Data(contentsOf: metadataFile)
                let photo = try JSONDecoder().decode(Photo.self, from: metadataData)
                
                // Check if photo already exists
                let existing = PhotoStorageService.shared.photos.first { $0.id == photo.id }
                
                var shouldImport = false
                switch options.mergeStrategy {
                case .skip:
                    shouldImport = (existing == nil)
                case .replace:
                    shouldImport = true
                case .keepBoth:
                    shouldImport = true
                }
                
                if shouldImport {
                    // Copy image file
                    let imageFileName = metadataFile.deletingPathExtension().lastPathComponent + ".jpg"
                    let sourceImagePath = categoryDir.appendingPathComponent(imageFileName)
                    
                    if let image = UIImage(contentsOfFile: sourceImagePath.path) {
                        _ = try PhotoStorageService.shared.savePhoto(
                            image,
                            captureDate: photo.captureDate,
                            categoryId: photo.categoryId,
                            isFaceBlurred: photo.isFaceBlurred,
                            weight: photo.weight,
                            bodyFatPercentage: photo.bodyFatPercentage
                        )
                        imported += 1
                    }
                }
                
                processedPhotos += 1
                progress(Float(processedPhotos) / Float(totalPhotos))
            }
        }
        
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
        
        for (index, metadataFile) in videoFiles.enumerated() {
            let metadataData = try Data(contentsOf: metadataFile)
            let video = try JSONDecoder().decode(Video.self, from: metadataData)
            
            // Check if video already exists
            VideoStorageService.shared.initialize()
            let existing = VideoStorageService.shared.videos.first { $0.id == video.id }
            
            var shouldImport = false
            switch options.mergeStrategy {
            case .skip:
                shouldImport = (existing == nil)
            case .replace:
                shouldImport = true
                if existing != nil {
                    try VideoStorageService.shared.deleteVideo(existing!)
                }
            case .keepBoth:
                shouldImport = true
            }
            
            if shouldImport {
                // Copy video file
                let videoFileName = metadataFile.deletingPathExtension().lastPathComponent + ".mp4"
                let sourceVideoPath = directory.appendingPathComponent(videoFileName)
                
                if FileManager.default.fileExists(atPath: sourceVideoPath.path) {
                    _ = try await VideoStorageService.shared.saveVideo(
                        sourceVideoPath,
                        startDate: video.startDate,
                        endDate: video.endDate,
                        frameCount: video.frameCount
                    )
                    imported += 1
                }
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
            case .keepBoth:
                // For weight entries, we can't have multiple entries for same date
                shouldImport = (existing == nil)
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
            let existing = try await DailyNoteStorageService.shared.getNote(for: note.date)
            
            var shouldImport = false
            switch options.mergeStrategy {
            case .skip:
                shouldImport = (existing == nil)
            case .replace:
                shouldImport = true
            case .keepBoth:
                // For daily notes, we can't have multiple notes for same date
                shouldImport = (existing == nil)
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