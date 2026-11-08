import Foundation
import UIKit
import AVFoundation

class VideoStorageService {
    static let shared = VideoStorageService()
    
    private init() {}
    
    var documentsDirectory: URL {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            // これは発生しないはずだが、フォールバックとして一時ディレクトリを使用
            return FileManager.default.temporaryDirectory
        }
        return url
    }
    
    var videosDirectory: URL {
        documentsDirectory.appendingPathComponent("Videos")
    }
    
    var thumbnailsDirectory: URL {
        documentsDirectory.appendingPathComponent("Thumbnails")
    }
    
    private var metadataURL: URL {
        documentsDirectory.appendingPathComponent("videos_metadata.json")
    }
    
    private(set) var videos: [Video] = []
    /// メタデータをディスクから読んだか。読まずに保存すると既存の動画一覧を上書きしてしまう。
    private var hasLoadedMetadata = false
    
    func initialize() {
        createDirectoriesIfNeeded()
        loadVideosMetadata()
        hasLoadedMetadata = true
    }

    /// ギャラリーを開く前 (起動直後) に動画を保存・削除しても、置き場があり一覧を読み込み済みにする
    private func prepareForWrite() {
        if hasLoadedMetadata {
            createDirectoriesIfNeeded()
        } else {
            initialize()
        }
    }
    
    private func createDirectoriesIfNeeded() {
        try? FileManager.default.createDirectory(at: videosDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
    }
    
    func saveVideo(_ videoURL: URL, startDate: Date, endDate: Date, frameCount: Int) async throws -> Video {
        prepareForWrite()
        let fileName = "\(UUID().uuidString).mp4"
        let destinationURL = videosDirectory.appendingPathComponent(fileName)
        
        try FileManager.default.copyItem(at: videoURL, to: destinationURL)
        MediaFileProtection.apply(to: destinationURL)
        
        let asset = AVAsset(url: destinationURL)
        let duration = await loadDuration(for: asset)
        
        let thumbnailFileName = "\(UUID().uuidString).jpg"
        generateThumbnail(from: destinationURL, to: thumbnailFileName)
        
        let video = Video(
            fileName: fileName,
            duration: duration,
            startDate: startDate,
            endDate: endDate,
            frameCount: frameCount,
            thumbnailFileName: thumbnailFileName
        )
        
        videos.append(video)
        videos.sort { $0.createdDate > $1.createdDate }
        
        saveVideosMetadata()
        
        return video
    }
    
    private func loadDuration(for asset: AVAsset) async -> TimeInterval {
        do {
            let duration = try await asset.load(.duration)
            return duration.seconds
        } catch {
            // 再生時間の読み込みに失敗
            return 0
        }
    }
    
    func deleteVideo(_ video: Video) throws {
        prepareForWrite()
        let videoURL = videosDirectory.appendingPathComponent(video.fileName)
        try FileManager.default.removeItem(at: videoURL)
        
        if let thumbnailFileName = video.thumbnailFileName {
            let thumbnailURL = thumbnailsDirectory.appendingPathComponent(thumbnailFileName)
            try? FileManager.default.removeItem(at: thumbnailURL)
        }
        
        videos.removeAll { $0.id == video.id }
        saveVideosMetadata()
    }
    
    func loadThumbnail(for video: Video) -> UIImage? {
        guard let thumbnailURL = video.thumbnailURL,
              let imageData = try? Data(contentsOf: thumbnailURL) else { return nil }
        return UIImage(data: imageData)
    }
    
    private func generateThumbnail(from videoURL: URL, to fileName: String) {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 0, preferredTimescale: 1)
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let thumbnail = UIImage(cgImage: cgImage)
            
            if let data = thumbnail.jpegData(compressionQuality: 0.8) {
                let thumbnailURL = thumbnailsDirectory.appendingPathComponent(fileName)
                try data.write(to: thumbnailURL, options: [.atomic, MediaFileProtection.writingOptions])
            }
        } catch {
            // サムネイルの生成に失敗
        }
    }
    
    private func loadVideosMetadata() {
        guard let data = try? Data(contentsOf: metadataURL),
              let decoded = try? JSONDecoder().decode([Video].self, from: data) else {
            videos = []
            return
        }
        
        videos = decoded.sorted { $0.createdDate > $1.createdDate }
    }
    
    private func saveVideosMetadata() {
        guard let encoded = try? JSONEncoder().encode(videos) else { return }
        do {
            try encoded.write(to: metadataURL, options: .atomic)
        } catch {
            print("[VideoStorage] Failed to save videos metadata: \(error)")
        }
    }
}
