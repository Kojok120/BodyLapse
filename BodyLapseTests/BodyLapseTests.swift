import Foundation
import Testing
@testable import BodyLapse

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
}
