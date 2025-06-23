import Foundation
import UIKit

class PhotoStorageService {
    static let shared = PhotoStorageService()
    
    private init() {}
    
    var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var photosDirectory: URL {
        documentsDirectory.appendingPathComponent("Photos")
    }
    
    private var metadataURL: URL {
        documentsDirectory.appendingPathComponent("photos_metadata.json")
    }
    
    private(set) var photos: [Photo] = []
    
    func initialize() {
        createPhotosDirectoryIfNeeded()
        loadPhotosMetadata()
    }
    
    private func createPhotosDirectoryIfNeeded() {
        try? FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
    }
    
    func savePhoto(_ image: UIImage, isFaceBlurred: Bool = false, bodyDetectionConfidence: Double? = nil) throws -> Photo {
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw PhotoStorageError.compressionFailed
        }
        
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        
        try imageData.write(to: fileURL)
        
        let photo = Photo(
            fileName: fileName,
            isFaceBlurred: isFaceBlurred,
            bodyDetectionConfidence: bodyDetectionConfidence
        )
        
        photos.append(photo)
        photos.sort { $0.captureDate > $1.captureDate }
        
        savePhotosMetadata()
        
        return photo
    }
    
    func deletePhoto(_ photo: Photo) throws {
        let fileURL = photosDirectory.appendingPathComponent(photo.fileName)
        try FileManager.default.removeItem(at: fileURL)
        
        photos.removeAll { $0.id == photo.id }
        savePhotosMetadata()
    }
    
    func loadImage(for photo: Photo) -> UIImage? {
        let fileURL = photosDirectory.appendingPathComponent(photo.fileName)
        guard let imageData = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: imageData)
    }
    
    private func loadPhotosMetadata() {
        guard let data = try? Data(contentsOf: metadataURL),
              let decoded = try? JSONDecoder().decode([Photo].self, from: data) else {
            photos = []
            return
        }
        
        photos = decoded.sorted { $0.captureDate > $1.captureDate }
    }
    
    private func savePhotosMetadata() {
        guard let encoded = try? JSONEncoder().encode(photos) else { return }
        try? encoded.write(to: metadataURL)
    }
    
    func photosGroupedByDate() -> [(Date, [Photo])] {
        let grouped = Dictionary(grouping: photos) { photo in
            Calendar.current.startOfDay(for: photo.captureDate)
        }
        
        return grouped.sorted { $0.key > $1.key }
    }
}

enum PhotoStorageError: LocalizedError {
    case compressionFailed
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress the image"
        case .saveFailed:
            return "Failed to save the photo"
        }
    }
}