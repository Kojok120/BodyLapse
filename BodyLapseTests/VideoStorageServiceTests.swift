import Foundation
import Testing
@testable import BodyLapse

// アプリの Documents を共有する他のテスト (取り込み・書き出し) と競合しないよう、直列の BodyLapseTests に入れる
extension BodyLapseTests {

    /// 動画の置き場が無い状態 (ギャラリーを一度も開いていない) でも保存できる
    @Test
    func testSaveVideoCreatesMissingDirectories() async throws {
        let fileManager = FileManager.default
        let service = VideoStorageService.shared
        let videosDir = service.videosDirectory
        let stash = fileManager.temporaryDirectory.appendingPathComponent("VideosStash_\(UUID().uuidString)")

        let hadVideosDir = fileManager.fileExists(atPath: videosDir.path)
        if hadVideosDir {
            try fileManager.moveItem(at: videosDir, to: stash)
        }
        defer {
            try? fileManager.removeItem(at: videosDir)
            if hadVideosDir {
                try? fileManager.moveItem(at: stash, to: videosDir)
            }
        }

        let source = fileManager.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
        try Data("not-a-real-video".utf8).write(to: source)
        defer { try? fileManager.removeItem(at: source) }

        let video = try await service.saveVideo(source, startDate: Date(), endDate: Date(), frameCount: 1)
        #expect(fileManager.fileExists(atPath: videosDir.appendingPathComponent(video.fileName).path))

        try service.deleteVideo(video)
        #expect(!service.videos.contains { $0.id == video.id })
    }
}
