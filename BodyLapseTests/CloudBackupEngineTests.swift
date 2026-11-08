import Foundation
import Testing
@testable import BodyLapse

/// メモリ上の置き場 (CloudKit の代わり)
final class InMemoryBackupStore: CloudBackupStore {
    var media: [String: Data] = [:]
    var manifest: (data: Data, tag: String, createdAt: Date)?
    var legacy: (data: Data, createdAt: Date)?
    var uploadCalls: [[String]] = []
    var deleteCalls: [[String]] = []
    var failUploadAfter: Int?
    /// 写真・動画を上げている途中に呼ぶ (別の端末が割り込む状況を作る)
    var onUpload: (() -> Void)?
    private var tagCounter = 0

    private func nextTag() -> String {
        tagCounter += 1
        return "tag-\(tagCounter)"
    }

    func prepare() async throws {}

    func fetchSnapshot() async throws -> CloudBackupPlanner.CloudSnapshot {
        CloudBackupPlanner.CloudSnapshot(
            manifestTag: manifest?.tag,
            manifestCreatedAt: manifest?.createdAt,
            legacyBackupDate: legacy?.createdAt
        )
    }

    func existingMediaRecordNames(among names: [String]) async throws -> Set<String> {
        Set(names.filter { media[$0] != nil })
    }

    func uploadMedia(_ items: [(recordName: String, fileURL: URL)]) async throws {
        if let limit = failUploadAfter, uploadCalls.flatMap({ $0 }).count + items.count > limit {
            throw URLError(.networkConnectionLost)
        }
        onUpload?()
        uploadCalls.append(items.map(\.recordName))
        for item in items {
            media[item.recordName] = try Data(contentsOf: item.fileURL)
        }
    }

    func saveManifest(fileURL: URL, createdAt: Date, expectedTag: String?) async throws -> String {
        guard manifest?.tag == expectedTag else { throw CloudBackupStoreError.manifestChanged }
        let tag = nextTag()
        manifest = (try Data(contentsOf: fileURL), tag, createdAt)
        return tag
    }

    func downloadManifest(to destination: URL) async throws -> String {
        guard let manifest else { throw CloudBackupStoreError.notFound }
        try manifest.data.write(to: destination)
        return manifest.tag
    }

    func downloadMedia(_ items: [(recordName: String, destination: URL)]) async throws -> [String] {
        var missing: [String] = []
        for item in items {
            guard let data = media[item.recordName] else {
                missing.append(item.recordName)
                continue
            }
            try FileManager.default.createDirectory(at: item.destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: item.destination)
        }
        return missing
    }

    func deleteMedia(recordNames: [String]) async throws {
        deleteCalls.append(recordNames)
        for name in recordNames { media[name] = nil }
    }

    func downloadLegacy(to destination: URL) async throws {
        guard let legacy else { throw CloudBackupStoreError.notFound }
        try legacy.data.write(to: destination)
    }

    func deleteLegacy() async throws {
        legacy = nil
    }
}

struct CloudBackupEngineTests {

    /// 書き出しと同じ形の入力を作る (写真ファイル + 小さなデータ)
    private final class Fixture {
        let root: URL
        let work: URL
        let store = InMemoryBackupStore()
        var engine: CloudBackupEngine { CloudBackupEngine(store: store) }
        var state = CloudBackupPlanner.LocalState()

        init() throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent("CloudBackupEngineTests_\(UUID().uuidString)")
            work = root.appendingPathComponent("work")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }

        deinit {
            try? FileManager.default.removeItem(at: root)
        }

        func photoFile(_ name: String, contents: String) throws -> URL {
            let url = root.appendingPathComponent("src/\(name)")
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(contents.utf8).write(to: url)
            return url
        }

        func entries(photos: [String], weights: String = "[]") throws -> [SimpleZipArchive.ArchiveEntry] {
            var result: [SimpleZipArchive.ArchiveEntry] = []
            for name in photos {
                result.append(.init(path: "photos/default/\(name)", source: .file(try photoFile(name, contents: "image-\(name)"))))
                result.append(.init(path: "photos/default/\(name).json", source: .data(Data("{\"name\":\"\(name)\"}".utf8))))
            }
            result.append(.init(path: "data/weight_data.json", source: .data(Data(weights.utf8))))
            result.append(.init(path: "manifest.json", source: .data(Data("{}".utf8))))
            return result
        }

        @discardableResult
        func backup(photos: [String], weights: String = "[]", earliest: Date? = nil, force: Bool = false) async throws -> CloudBackupEngine.BackupOutcome {
            let outcome = try await engine.backup(
                entries: try entries(photos: photos, weights: weights),
                local: state,
                localEarliestPhotoDate: earliest,
                force: force,
                workDirectory: work,
                persist: { self.state = $0 }
            )
            state = outcome.state
            return outcome
        }
    }

    @Test
    func testBackupThenRestoreRoundTrips() async throws {
        let fixture = try Fixture()
        let first = try await fixture.backup(photos: ["a.jpg", "b.jpg"], weights: "[1]")
        #expect(first.uploadedCount == 2)
        #expect(fixture.store.media.count == 2)

        // 別の端末 (まっさら) で復元する
        let restored = try await fixture.engine.restore(local: .init(), workDirectory: fixture.root.appendingPathComponent("restore"))
        let dir = restored.extractedDirectory
        #expect(try String(contentsOf: dir.appendingPathComponent("photos/default/a.jpg")) == "image-a.jpg")
        #expect(try String(contentsOf: dir.appendingPathComponent("photos/default/b.jpg.json")).contains("b.jpg"))
        #expect(try String(contentsOf: dir.appendingPathComponent("data/weight_data.json")) == "[1]")
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("manifest.json").path))
        #expect(restored.missingMediaCount == 0)
        #expect(restored.state.manifestTag == fixture.store.manifest?.tag)
    }

    @Test
    func testSecondBackupUploadsOnlyNewAndDeletesRemoved() async throws {
        let fixture = try Fixture()
        try await fixture.backup(photos: ["a.jpg", "b.jpg"])
        let second = try await fixture.backup(photos: ["b.jpg", "c.jpg"])
        #expect(second.uploadedCount == 1)
        #expect(fixture.store.uploadCalls.last == [CloudBackupPlanner.recordName(forMediaPath: "photos/default/c.jpg")])
        #expect(second.deletedCount == 1)
        #expect(fixture.store.media[CloudBackupPlanner.recordName(forMediaPath: "photos/default/a.jpg")] == nil)
        #expect(fixture.store.media.count == 2)
    }

    @Test
    func testFreshDeviceDoesNotOverwriteExistingBackup() async throws {
        let fixture = try Fixture()
        try await fixture.backup(photos: ["a.jpg", "b.jpg"])
        let tagBefore = fixture.store.manifest?.tag

        // 再インストール: 端末の記録が無い状態で 1 枚だけ撮った
        fixture.state = .init()
        await #expect(throws: CloudBackupError.needsDecision(.otherBackup)) {
            try await fixture.backup(photos: ["new.jpg"])
        }
        #expect(fixture.store.manifest?.tag == tagBefore)
        #expect(fixture.store.media.count == 2)
    }

    @Test
    func testForceReplaceKeepsSharedMediaAndRemovesTheRest() async throws {
        let fixture = try Fixture()
        try await fixture.backup(photos: ["a.jpg", "b.jpg"])
        fixture.state = .init()
        let outcome = try await fixture.backup(photos: ["b.jpg", "new.jpg"], force: true)
        #expect(outcome.uploadedCount == 1)
        #expect(Set(fixture.store.media.keys) == Set(["photos/default/b.jpg", "photos/default/new.jpg"].map(CloudBackupPlanner.recordName(forMediaPath:))))
    }

    @Test
    func testInterruptedUploadResumesWithoutReuploading() async throws {
        let fixture = try Fixture()
        fixture.store.failUploadAfter = 8
        let photos = (0..<12).map { "p\($0).jpg" }
        await #expect(throws: (any Error).self) {
            try await fixture.backup(photos: photos)
        }
        #expect(fixture.store.manifest == nil)
        #expect(fixture.state.uploadedRecordNames.count == 8)

        fixture.store.failUploadAfter = nil
        let resumed = try await fixture.backup(photos: photos)
        #expect(resumed.uploadedCount == 4)
        #expect(fixture.store.media.count == 12)
    }

    @Test
    func testConcurrentWriterIsDetected() async throws {
        let fixture = try Fixture()
        try await fixture.backup(photos: ["a.jpg"])
        let store = fixture.store
        // 自分が写真を上げている間に、別の端末が目録を書き換えた
        store.onUpload = {
            if let current = store.manifest {
                store.manifest = (current.data, "other-device", current.createdAt)
            }
        }
        await #expect(throws: CloudBackupError.conflict) {
            try await fixture.backup(photos: ["a.jpg", "b.jpg"])
        }
        #expect(store.manifest?.tag == "other-device")
    }

    @Test
    func testLegacyBackupIsMigratedOnTheSameDevice() async throws {
        let fixture = try Fixture()
        let legacyDate = Date(timeIntervalSince1970: 1_800_000_000)
        fixture.store.legacy = (Data("old".utf8), legacyDate)

        // まっさらな端末 (写真がバックアップより後だけ) は止める
        await #expect(throws: CloudBackupError.needsDecision(.legacyBackup)) {
            try await fixture.backup(photos: ["new.jpg"], earliest: legacyDate.addingTimeInterval(60))
        }
        #expect(fixture.store.legacy != nil)

        // 同じ端末 (バックアップより前の写真がある) なら新形式で上げ、旧形式を消す
        try await fixture.backup(photos: ["old.jpg", "new.jpg"], earliest: legacyDate.addingTimeInterval(-86_400))
        #expect(fixture.store.manifest != nil)
        #expect(fixture.store.legacy == nil)
    }

    @Test
    func testRestoreFromLegacyBackup() async throws {
        let fixture = try Fixture()
        let legacyZip = fixture.root.appendingPathComponent("legacy.bodylapse")
        #expect(SimpleZipArchive.createArchive(atPath: legacyZip.path, entries: [
            .init(path: "manifest.json", source: .data(Data("{}".utf8))),
            .init(path: "photos/default/a.jpg", source: .data(Data("legacy-a".utf8)))
        ]))
        let legacyDate = Date(timeIntervalSince1970: 1_800_000_000)
        fixture.store.legacy = (try Data(contentsOf: legacyZip), legacyDate)

        let restored = try await fixture.engine.restore(local: .init(), workDirectory: fixture.root.appendingPathComponent("restore"))
        #expect(try String(contentsOf: restored.extractedDirectory.appendingPathComponent("photos/default/a.jpg")) == "legacy-a")
        #expect(restored.state.acknowledgedLegacyBackupDate == legacyDate)

        // 復元した後は、その続きとして上げてよい
        fixture.state = restored.state
        try await fixture.backup(photos: ["a.jpg"], earliest: legacyDate.addingTimeInterval(60))
        #expect(fixture.store.legacy == nil)
    }

    @Test
    func testRestoreWithoutBackupFails() async throws {
        let fixture = try Fixture()
        await #expect(throws: CloudBackupError.noBackup) {
            _ = try await fixture.engine.restore(local: .init(), workDirectory: fixture.work)
        }
    }
}
