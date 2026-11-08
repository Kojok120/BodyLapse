import Foundation
import Testing
@testable import BodyLapse

struct MediaFileProtectionTests {

    @Test
    func testMigrateRunsOnceAndProtectsExistingFiles() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("MediaFileProtectionTests-\(UUID().uuidString)")
        let category = root.appendingPathComponent("default", isDirectory: true)
        try fileManager.createDirectory(at: category, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }
        let photo = category.appendingPathComponent("a.jpg")
        try Data([0xFF, 0xD8]).write(to: photo)

        let suiteName = "MediaFileProtectionTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        MediaFileProtection.migrateIfNeeded(directories: [root, root.appendingPathComponent("missing")], defaults: defaults)
        #expect(defaults.integer(forKey: MediaFileProtection.migrationVersionKey) == MediaFileProtection.migrationVersion)

        // シミュレータは保護を強制しないが、属性を返すときは当たっていること
        if let protection = try fileManager.attributesOfItem(atPath: photo.path)[.protectionKey] as? FileProtectionType {
            #expect(protection == MediaFileProtection.protection)
        }
        // ファイルはそのまま読める (ロックしていない)
        #expect(try Data(contentsOf: photo) == Data([0xFF, 0xD8]))
    }
}
