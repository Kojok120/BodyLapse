import Foundation
import Testing
import UIKit
@testable import BodyLapse

// アプリのシングルトン（PhotoStorageService等）と共有Documentsディレクトリを
// 操作するテストがあるため、直列実行にする
@Suite(.serialized)
struct BodyLapseTests {

    @Test
    func testSimpleZipArchiveRoundTripNestedPaths() throws {
        let fileManager = FileManager.default
        let tempRoot = fileManager.temporaryDirectory.appendingPathComponent("BodyLapseTests_\(UUID().uuidString)")
        let sourceDir = tempRoot.appendingPathComponent("source")
        let nestedDir = sourceDir.appendingPathComponent("nested")
        let archiveURL = tempRoot.appendingPathComponent("archive.bodylapse")
        let outputDir = tempRoot.appendingPathComponent("output")

        try fileManager.createDirectory(at: nestedDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempRoot) }

        let topLevelFile = sourceDir.appendingPathComponent("top.txt")
        let nestedFile = nestedDir.appendingPathComponent("inner.txt")
        try Data("top-level".utf8).write(to: topLevelFile)
        try Data("nested-value".utf8).write(to: nestedFile)

        #expect(SimpleZipArchive.createZipFile(atPath: archiveURL.path, withContentsOfDirectory: sourceDir.path))
        #expect(SimpleZipArchive.unzipFile(atPath: archiveURL.path, toDestination: outputDir.path))

        let extractedTop = outputDir.appendingPathComponent("top.txt")
        let extractedNested = outputDir.appendingPathComponent("nested/inner.txt")

        let extractedTopData = try Data(contentsOf: extractedTop)
        let extractedNestedData = try Data(contentsOf: extractedNested)
        #expect(extractedTopData == Data("top-level".utf8))
        #expect(extractedNestedData == Data("nested-value".utf8))
    }

    @Test
    func testSimpleZipArchiveRejectsParentTraversal() throws {
        let fileManager = FileManager.default
        let tempRoot = fileManager.temporaryDirectory.appendingPathComponent("BodyLapseTests_\(UUID().uuidString)")
        let archiveURL = tempRoot.appendingPathComponent("malicious.bodylapse")
        let destinationDir = tempRoot.appendingPathComponent("extract")

        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempRoot) }

        try Self.writeArchive(at: archiveURL, entryPath: "../escape.txt", payload: Data("owned".utf8))

        #expect(!SimpleZipArchive.unzipFile(atPath: archiveURL.path, toDestination: destinationDir.path))

        let escapedFile = destinationDir.deletingLastPathComponent().appendingPathComponent("escape.txt")
        #expect(!fileManager.fileExists(atPath: escapedFile.path))
    }

    @Test
    func testSimpleZipArchiveRejectsAbsolutePath() throws {
        let fileManager = FileManager.default
        let tempRoot = fileManager.temporaryDirectory.appendingPathComponent("BodyLapseTests_\(UUID().uuidString)")
        let archiveURL = tempRoot.appendingPathComponent("absolute.bodylapse")
        let destinationDir = tempRoot.appendingPathComponent("extract")
        let absoluteTarget = "/tmp/bodylapse_abs_\(UUID().uuidString).txt"

        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: tempRoot)
            try? fileManager.removeItem(atPath: absoluteTarget)
        }

        try Self.writeArchive(at: archiveURL, entryPath: absoluteTarget, payload: Data("owned".utf8))

        #expect(!SimpleZipArchive.unzipFile(atPath: archiveURL.path, toDestination: destinationDir.path))
        #expect(!fileManager.fileExists(atPath: absoluteTarget))
    }

    @Test
    func testContentViewDestinationRouting() {
        #expect(
            ContentView.destination(
                hasCompletedOnboarding: false,
                isAuthenticationEnabled: true,
                isAuthenticated: false
            ) == .onboarding
        )

        #expect(
            ContentView.destination(
                hasCompletedOnboarding: true,
                isAuthenticationEnabled: true,
                isAuthenticated: false
            ) == .authentication
        )

        #expect(
            ContentView.destination(
                hasCompletedOnboarding: true,
                isAuthenticationEnabled: false,
                isAuthenticated: false
            ) == .main
        )

        #expect(
            ContentView.destination(
                hasCompletedOnboarding: true,
                isAuthenticationEnabled: true,
                isAuthenticated: true
            ) == .main
        )
    }

    @Test
    func testImportExportServiceExportsArchiveContents() async throws {
        try Self.resetAppData()

        let fileManager = FileManager.default
        let tempRoot = fileManager.temporaryDirectory.appendingPathComponent("BodyLapseExportTest_\(UUID().uuidString)")
        let extractDir = tempRoot.appendingPathComponent("extract")
        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempRoot)
        }

        let captureDate = Date(timeIntervalSince1970: 1_700_000_000)
        let image = Self.makeTestImage()
        let photo = try PhotoStorageService.shared.savePhoto(
            image,
            captureDate: captureDate,
            categoryId: PhotoCategory.defaultCategory.id,
            weight: 72.4,
            bodyFatPercentage: 18.1
        )

        try await WeightStorageService.shared.saveEntry(
            WeightEntry(
                date: captureDate,
                weight: 72.4,
                bodyFatPercentage: 18.1
            )
        )
        try await DailyNoteStorageService.shared.saveNote(for: captureDate, content: "Regression note")

        let exportURL = try await Self.exportArchive(
            options: ImportExportService.ExportOptions(
                includePhotos: true,
                includeVideos: false,
                includeSettings: true,
                includeWeightData: true,
                includeNotes: true,
                dateRange: nil,
                categories: nil
            )
        )

        defer {
            try? fileManager.removeItem(at: exportURL)
        }

        #expect(SimpleZipArchive.unzipFile(atPath: exportURL.path, toDestination: extractDir.path))

        let manifestURL = extractDir.appendingPathComponent("manifest.json")
        let categoriesURL = extractDir.appendingPathComponent("data/categories.json")
        let weightURL = extractDir.appendingPathComponent("data/weight_data.json")
        let notesURL = extractDir.appendingPathComponent("data/notes.json")
        let settingsURL = extractDir.appendingPathComponent("data/settings.json")
        let photoURL = extractDir
            .appendingPathComponent("photos")
            .appendingPathComponent(photo.categoryId)
            .appendingPathComponent(photo.fileName)
        let photoMetadataURL = extractDir
            .appendingPathComponent("photos")
            .appendingPathComponent(photo.categoryId)
            .appendingPathComponent("\(photo.id.uuidString).json")

        #expect(fileManager.fileExists(atPath: manifestURL.path))
        #expect(fileManager.fileExists(atPath: categoriesURL.path))
        #expect(fileManager.fileExists(atPath: weightURL.path))
        #expect(fileManager.fileExists(atPath: notesURL.path))
        #expect(fileManager.fileExists(atPath: settingsURL.path))
        #expect(fileManager.fileExists(atPath: photoURL.path))
        #expect(fileManager.fileExists(atPath: photoMetadataURL.path))

        let manifest = try Self.decodeExportManifest(from: manifestURL)
        #expect(manifest.dataInfo.photoCount == 1)
        #expect(manifest.dataInfo.videoCount == 0)
        #expect(manifest.dataInfo.categoryCount == 1)
        #expect(manifest.dataInfo.weightEntryCount == 1)
        #expect(manifest.dataInfo.noteCount == 1)

        let weightEntries = try Self.decode([WeightEntry].self, from: weightURL)
        let notes = try Self.decode([DailyNote].self, from: notesURL)
        #expect(weightEntries.count == 1)
        #expect(notes.count == 1)

        try Self.resetAppData()
    }

    @Test
    func testImportRestoresDataAndAvoidsDuplicates() async throws {
        try Self.resetAppData()

        let fileManager = FileManager.default
        let captureDate = Date(timeIntervalSince1970: 1_700_000_000)
        let image = Self.makeTestImage()
        _ = try PhotoStorageService.shared.savePhoto(
            image,
            captureDate: captureDate,
            categoryId: PhotoCategory.defaultCategory.id,
            weight: 70.0,
            bodyFatPercentage: 16.0
        )
        try await WeightStorageService.shared.saveEntry(
            WeightEntry(date: captureDate, weight: 70.0, bodyFatPercentage: 16.0)
        )

        let exportURL = try await Self.exportArchive(
            options: ImportExportService.ExportOptions(
                includePhotos: true,
                includeVideos: false,
                includeSettings: false,
                includeWeightData: true,
                includeNotes: false,
                dateRange: nil,
                categories: nil
            )
        )
        defer { try? fileManager.removeItem(at: exportURL) }

        // 復元シナリオ: 全データを消去してからインポート
        // （resetAppDataがWeightDataディレクトリごと削除する）
        try Self.resetAppData()

        let restoreSummary = try await Self.importArchive(from: exportURL, options: .default)
        #expect(restoreSummary.photosImported == 1)
        #expect(restoreSummary.weightEntriesImported == 1)
        #expect(PhotoStorageService.shared.photos.count == 1)

        // 同じアーカイブを skip 戦略で再インポート → 重複しない
        let skipSummary = try await Self.importArchive(from: exportURL, options: .default)
        #expect(skipSummary.photosImported == 0)
        #expect(skipSummary.weightEntriesImported == 0)
        #expect(PhotoStorageService.shared.photos.count == 1)

        // replace 戦略で再インポート → 置換され、件数は増えない
        let replaceSummary = try await Self.importArchive(
            from: exportURL,
            options: ImportExportService.ImportOptions(
                mergeStrategy: .replace,
                importPhotos: true,
                importVideos: false,
                importSettings: false,
                importWeightData: true,
                importNotes: false
            )
        )
        #expect(replaceSummary.photosImported == 1)
        #expect(PhotoStorageService.shared.photos.count == 1)
        let restoredPhoto = try #require(PhotoStorageService.shared.photos.first)
        #expect(restoredPhoto.weight == 70.0)
        #expect(restoredPhoto.bodyFatPercentage == 16.0)
        #expect(Calendar.current.isDate(restoredPhoto.captureDate, inSameDayAs: captureDate))

        let weightEntries = try await WeightStorageService.shared.loadEntries()
        #expect(weightEntries.count == 1)

        try Self.resetAppData()
    }

    private static func importArchive(
        from url: URL,
        options: ImportExportService.ImportOptions
    ) async throws -> ImportExportService.ImportSummary {
        try await withCheckedThrowingContinuation { continuation in
            ImportExportService.shared.importData(from: url, options: options, progress: { _ in }) { result in
                continuation.resume(with: result)
            }
        }
    }

    private static func writeArchive(at url: URL, entryPath: String, payload: Data) throws {
        var data = Data()
        data.append(contentsOf: [0x42, 0x4f, 0x44, 0x59]) // BODY

        appendLE(UInt16(1), to: &data)
        appendLE(UInt32(1), to: &data)

        let pathData = Data(entryPath.utf8)
        appendLE(UInt32(pathData.count), to: &data)
        data.append(pathData)

        appendLE(UInt64(payload.count), to: &data)
        data.append(payload)

        try data.write(to: url)
    }

    private static func appendLE<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { bytes in
            data.append(contentsOf: bytes)
        }
    }

    private static func exportArchive(options: ImportExportService.ExportOptions) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            ImportExportService.shared.exportData(options: options, progress: { _ in }) { result in
                continuation.resume(with: result)
            }
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        return try decoder.decode(type, from: data)
    }

    private static func decodeExportManifest(from url: URL) throws -> ImportExportService.ExportManifest {
        try decode(ImportExportService.ExportManifest.self, from: url)
    }

    private static func makeTestImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        return renderer.image { context in
            UIColor.systemTeal.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }

    private static func resetAppData() throws {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let pathsToRemove = [
            "Photos",
            "Categories",
            "WeightData",
            "Notes",
            "Videos",
            "Thumbnails",
            "photos_metadata.json",
            "videos_metadata.json"
        ]

        for path in pathsToRemove {
            let url = documentsDirectory.appendingPathComponent(path)
            if fileManager.fileExists(atPath: url.path) {
                try? fileManager.removeItem(at: url)
            }
        }

        try? fileManager.createDirectory(
            at: documentsDirectory.appendingPathComponent("Categories"),
            withIntermediateDirectories: true
        )

        CategoryStorageService.shared.saveCategories([PhotoCategory.defaultCategory])
        PhotoStorageService.shared.initialize()
        PhotoStorageService.shared.reloadPhotosFromDisk(syncWeightData: false)
        VideoStorageService.shared.initialize()
    }
}
