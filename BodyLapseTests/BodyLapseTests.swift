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

// MARK: - PhotoStatistics（ストリーク計算）の純粋ロジックテスト
@Suite
struct PhotoStatisticsTests {
    /// 決定的にするため UTC 固定の Gregorian カレンダーを使う。
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth, hour: 12))!
    }

    @Test
    func emptyReturnsZeroes() {
        let stats = PhotoStatistics.compute(from: [], referenceDate: day(2026, 6, 15), calendar: calendar)
        #expect(stats == .empty)
        #expect(stats.currentStreak == 0)
        #expect(stats.isTodayCaptured == false)
    }

    @Test
    func todayOnlyIsStreakOne() {
        let stats = PhotoStatistics.compute(from: [day(2026, 6, 15)], referenceDate: day(2026, 6, 15), calendar: calendar)
        #expect(stats.currentStreak == 1)
        #expect(stats.longestStreak == 1)
        #expect(stats.totalDays == 1)
        #expect(stats.daysThisMonth == 1)
        #expect(stats.isTodayCaptured == true)
    }

    @Test
    func consecutiveDaysEndingTodayCountTowardStreak() {
        let days: Set<Date> = [day(2026, 6, 13), day(2026, 6, 14), day(2026, 6, 15)]
        let stats = PhotoStatistics.compute(from: days, referenceDate: day(2026, 6, 15), calendar: calendar)
        #expect(stats.currentStreak == 3)
        #expect(stats.longestStreak == 3)
        #expect(stats.isTodayCaptured == true)
    }

    @Test
    func streakStaysAliveWhenTodayNotYetCaptured() {
        // 今日(15日)は未撮影だが、昨日まで3日続いている → ストリークは生存(3)
        let days: Set<Date> = [day(2026, 6, 12), day(2026, 6, 13), day(2026, 6, 14)]
        let stats = PhotoStatistics.compute(from: days, referenceDate: day(2026, 6, 15), calendar: calendar)
        #expect(stats.currentStreak == 3)
        #expect(stats.isTodayCaptured == false)
    }

    @Test
    func brokenStreakResetsCurrentButKeepsLongest() {
        // 6/1-6/3 の3連続、間が空いて 6/15(今日)単独
        let days: Set<Date> = [day(2026, 6, 1), day(2026, 6, 2), day(2026, 6, 3), day(2026, 6, 15)]
        let stats = PhotoStatistics.compute(from: days, referenceDate: day(2026, 6, 15), calendar: calendar)
        #expect(stats.currentStreak == 1)
        #expect(stats.longestStreak == 3)
        #expect(stats.totalDays == 4)
    }

    @Test
    func daysThisMonthExcludesOtherMonths() {
        // 5/30, 5/31, 6/1。基準は6/15。今月(6月)の撮影日は1日だけ。
        let days: Set<Date> = [day(2026, 5, 30), day(2026, 5, 31), day(2026, 6, 1)]
        let stats = PhotoStatistics.compute(from: days, referenceDate: day(2026, 6, 15), calendar: calendar)
        #expect(stats.daysThisMonth == 1)
        #expect(stats.longestStreak == 3) // 月をまたいでも連続は連続
        #expect(stats.currentStreak == 0) // 今日・昨日に撮影なし
    }

    @Test
    func duplicateTimestampsOnSameDayCountOnce() {
        let days: Set<Date> = [
            calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 8))!,
            calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 20))!
        ]
        let stats = PhotoStatistics.compute(from: days, referenceDate: day(2026, 6, 15), calendar: calendar)
        #expect(stats.totalDays == 1)
        #expect(stats.currentStreak == 1)
    }
}

// MARK: - AchievementService（実績解除）のテスト
@Suite(.serialized)
@MainActor
struct AchievementServiceTests {
    private func stats(streak: Int, longest: Int, total: Int) -> PhotoStatistics {
        PhotoStatistics(currentStreak: streak, longestStreak: longest, daysThisMonth: total, totalDays: total, isTodayCaptured: true)
    }

    @Test
    func unlocksStreakMilestonesAndIsIdempotent() {
        let service = AchievementService.shared
        service.resetForDebug()
        defer { service.resetForDebug() }

        // 最長7日 → streak_3 と streak_7 が解除される
        let first = service.evaluate(stats(streak: 7, longest: 7, total: 7), notify: false)
        #expect(Set(first.map { $0.id }) == ["streak_3", "streak_7"])

        // 同じ統計で再評価しても新規解除はない（冪等）
        let second = service.evaluate(stats(streak: 7, longest: 7, total: 7), notify: false)
        #expect(second.isEmpty)
    }

    @Test
    func unlocksTotalDaysMilestoneIndependentlyOfStreak() {
        let service = AchievementService.shared
        service.resetForDebug()
        defer { service.resetForDebug() }

        // 通算30日・最長5日 → total_30 は解除、streak_7 は未解除
        let unlocked = service.evaluate(stats(streak: 1, longest: 5, total: 30), notify: false)
        #expect(unlocked.contains { $0.id == "total_30" })
        #expect(!unlocked.contains { $0.id == "streak_7" })
    }

    @Test
    func belowThresholdUnlocksNothing() {
        let service = AchievementService.shared
        service.resetForDebug()
        defer { service.resetForDebug() }

        let unlocked = service.evaluate(stats(streak: 2, longest: 2, total: 2), notify: false)
        #expect(unlocked.isEmpty)
    }
}

// MARK: - ProgressInsight（進捗インサイト/目標）の純粋ロジックテスト
@Suite
struct ProgressInsightTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// 基準日から offsetDays 日前のエントリを作る（weight は kg）。
    private func entry(daysAgo: Int, weight: Double, from base: Date) -> WeightEntry {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: base)!
        return WeightEntry(date: date, weight: weight)
    }

    @Test
    func emptyReturnsEmpty() {
        let insight = ProgressInsight.compute(entries: [], calendar: calendar)
        #expect(insight == .empty)
        #expect(insight.hasData == false)
    }

    @Test
    func computesTotalAndRecentChange() {
        let base = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 12))!
        // 60日前 80kg → 30日前 78kg → 当日 75kg
        let entries = [
            entry(daysAgo: 60, weight: 80, from: base),
            entry(daysAgo: 30, weight: 78, from: base),
            entry(daysAgo: 0, weight: 75, from: base)
        ]
        let insight = ProgressInsight.compute(entries: entries, calendar: calendar)
        #expect(insight.currentWeight == 75)
        #expect(insight.startWeight == 80)
        #expect(insight.totalChange == -5)
        // 直近30日: 30日前(78) を基準に 75-78 = -3
        #expect(insight.recentChange == -3)
        // 週次ペースは減少なので負
        #expect((insight.weeklyRate ?? 0) < 0)
    }

    @Test
    func goalProgressFractionAndProjection() {
        let base = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 12))!
        // 直線的に減少：60日前80kg → 当日75kg、目標70kg
        let entries = (0...6).map { i in
            entry(daysAgo: 60 - i * 10, weight: 80 - Double(i) * (5.0 / 6.0), from: base)
        }
        let insight = ProgressInsight.compute(entries: entries, goalWeight: 70, calendar: calendar)
        #expect(insight.goalWeight == 70)
        #expect(insight.hasReachedGoal == false)
        // start80, current75, goal70 → (80-75)/(80-70)=0.5
        #expect(abs((insight.progressFraction ?? 0) - 0.5) < 0.01)
        // 減少中で目標は下なので達成予定日が出る
        #expect(insight.projectedGoalDate != nil)
        // あと約5kg
        #expect(abs((insight.remainingToGoal ?? 0) - 5) < 0.01)
    }

    @Test
    func reachedGoalWhenLosing() {
        let base = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 12))!
        let entries = [
            entry(daysAgo: 30, weight: 75, from: base),
            entry(daysAgo: 0, weight: 69, from: base)
        ]
        let insight = ProgressInsight.compute(entries: entries, goalWeight: 70, calendar: calendar)
        #expect(insight.hasReachedGoal == true)
        #expect(insight.progressFraction == 1)
    }

    @Test
    func noProjectionWhenMovingAwayFromGoal() {
        let base = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 12))!
        // 体重が増加しているのに目標は下 → 達成予定は出ない
        let entries = [
            entry(daysAgo: 30, weight: 72, from: base),
            entry(daysAgo: 0, weight: 76, from: base)
        ]
        let insight = ProgressInsight.compute(entries: entries, goalWeight: 70, calendar: calendar)
        #expect(insight.hasReachedGoal == false)
        #expect(insight.projectedGoalDate == nil)
    }
}

// MARK: - NotificationService の文面選択ロジック
@Suite
struct NotificationServiceTests {
    @Test
    func streakBodyOnlyForTodayWithActiveStreak() {
        // 当日かつ連続2日以上 → ストリーク文言
        #expect(NotificationService.reminderBodyKey(currentStreak: 5, isToday: true) == "notification.streak_at_risk_body")
        // 将来日は連続日数があっても通常文言（古い値の固定表示を防ぐ）
        #expect(NotificationService.reminderBodyKey(currentStreak: 5, isToday: false) == "notification.no_photo_body")
        // 連続1日以下は当日でも通常文言
        #expect(NotificationService.reminderBodyKey(currentStreak: 1, isToday: true) == "notification.no_photo_body")
        #expect(NotificationService.reminderBodyKey(currentStreak: 0, isToday: true) == "notification.no_photo_body")
    }
}

// MARK: - PaywallPromptManager（表示済みフラグ）
@Suite(.serialized)
@MainActor
struct PaywallPromptManagerTests {
    @Test
    func tracksShownStateIndependentlyAndResets() {
        let manager = PaywallPromptManager.shared
        manager.resetForDebug()
        defer { manager.resetForDebug() }

        #expect(manager.hasShown(.milestoneCloud) == false)
        #expect(manager.hasShown(.shareWatermark) == false)

        manager.markShown(.milestoneCloud)
        #expect(manager.hasShown(.milestoneCloud) == true)
        // 片方をマークしても他方は未表示のまま
        #expect(manager.hasShown(.shareWatermark) == false)

        manager.resetForDebug()
        #expect(manager.hasShown(.milestoneCloud) == false)
    }
}
