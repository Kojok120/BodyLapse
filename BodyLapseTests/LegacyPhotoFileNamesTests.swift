import Foundation
import Testing
@testable import BodyLapse

struct LegacyPhotoFileNamesTests {
    @Test
    func testListsOnlyFilesDirectlyUnderPhotos() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("LegacyPhotos-\(UUID().uuidString)")
        try fileManager.createDirectory(at: root.appendingPathComponent("default"), withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }
        try Data([1]).write(to: root.appendingPathComponent("old.jpg"))
        try Data([1]).write(to: root.appendingPathComponent("default/new.jpg"))

        #expect(PhotoStorageService.legacyPhotoFileNames(in: root) == ["old.jpg"])
        #expect(PhotoStorageService.legacyPhotoFileNames(in: root.appendingPathComponent("missing")).isEmpty)
    }
}
