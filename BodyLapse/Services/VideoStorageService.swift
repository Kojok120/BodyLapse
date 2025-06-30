import Foundation
import UIKit
import AVFoundation

class VideoStorageService {
    static let shared = VideoStorageService()
    
    private init() {}
    
    var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
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
    
    func initialize() {
        createDirectoriesIfNeeded()
        loadVideosMetadata()
    }
    
    private func createDirectoriesIfNeeded() {
        try? FileManager.default.createDirectory(at: videosDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
    }
    
    func saveVideo(_ videoURL: URL, startDate: Date, endDate: Date, frameCount: Int) async throws -> Video {
        let fileName = "\(UUID().uuidString).mp4"
        let destinationURL = videosDirectory.appendingPathComponent(fileName)
        
        try FileManager.default.copyItem(at: videoURL, to: destinationURL)
        
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
            // Failed to load duration
            return 0
        }
    }
    
    func deleteVideo(_ video: Video) throws {
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
                try data.write(to: thumbnailURL)
            }
        } catch {
            // Failed to generate thumbnail
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
        try? encoded.write(to: metadataURL)
    }
}

enum VideoStorageError: LocalizedError {
    case saveFailed
    case thumbnailGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Failed to save the video"
        case .thumbnailGenerationFailed:
            return "Failed to generate video thumbnail"
        }
    }
}