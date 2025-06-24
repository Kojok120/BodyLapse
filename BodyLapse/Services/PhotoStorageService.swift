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
        print("[PhotoStorage] Initializing...")
        createPhotosDirectoryIfNeeded()
        loadPhotosMetadata()
        print("[PhotoStorage] Initialized with \(photos.count) photos")
    }
    
    private func createPhotosDirectoryIfNeeded() {
        try? FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
    }
    
    func savePhoto(_ image: UIImage, captureDate: Date = Date(), isFaceBlurred: Bool = false, bodyDetectionConfidence: Double? = nil, weight: Double? = nil, bodyFatPercentage: Double? = nil) throws -> Photo {
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw PhotoStorageError.compressionFailed
        }
        
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        
        try imageData.write(to: fileURL)
        
        let photo = Photo(
            captureDate: captureDate,
            fileName: fileName,
            isFaceBlurred: isFaceBlurred,
            bodyDetectionConfidence: bodyDetectionConfidence,
            weight: weight,
            bodyFatPercentage: bodyFatPercentage
        )
        
        photos.append(photo)
        photos.sort { $0.captureDate > $1.captureDate }
        
        savePhotosMetadata()
        
        return photo
    }
    
    func hasPhotoForToday() -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return photos.contains { photo in
            calendar.isDate(photo.captureDate, inSameDayAs: today)
        }
    }
    
    func getPhotoForDate(_ date: Date) -> Photo? {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        return photos.first { photo in
            calendar.isDate(photo.captureDate, inSameDayAs: targetDay)
        }
    }
    
    func replacePhoto(for date: Date, with image: UIImage, isFaceBlurred: Bool = false, bodyDetectionConfidence: Double? = nil, weight: Double? = nil, bodyFatPercentage: Double? = nil) throws -> Photo {
        print("[PhotoStorage] Replacing photo for date: \(date)")
        if let existingPhoto = getPhotoForDate(date) {
            print("[PhotoStorage] Found existing photo for date, deleting: \(existingPhoto.captureDate)")
            try deletePhoto(existingPhoto)
        }
        
        let newPhoto = try savePhoto(image, captureDate: date, isFaceBlurred: isFaceBlurred, bodyDetectionConfidence: bodyDetectionConfidence, weight: weight, bodyFatPercentage: bodyFatPercentage)
        print("[PhotoStorage] New photo saved with date: \(newPhoto.captureDate)")
        return newPhoto
    }
    
    func updatePhotoMetadata(_ photo: Photo, weight: Double?, bodyFatPercentage: Double?) {
        guard let index = photos.firstIndex(where: { $0.id == photo.id }) else { return }
        
        var updatedPhoto = photo
        updatedPhoto.weight = weight
        updatedPhoto.bodyFatPercentage = bodyFatPercentage
        
        photos[index] = updatedPhoto
        savePhotosMetadata()
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
        print("[PhotoStorage] Loading metadata from: \(metadataURL.path)")
        
        guard let data = try? Data(contentsOf: metadataURL) else {
            print("[PhotoStorage] No metadata file found")
            photos = []
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode([Photo].self, from: data)
            photos = decoded.sorted { $0.captureDate > $1.captureDate }
            print("[PhotoStorage] Loaded \(photos.count) photos from metadata")
        } catch {
            print("[PhotoStorage] Failed to decode metadata: \(error)")
            photos = []
        }
    }
    
    private func savePhotosMetadata() {
        do {
            let encoded = try JSONEncoder().encode(photos)
            try encoded.write(to: metadataURL)
            print("[PhotoStorage] Saved metadata for \(photos.count) photos")
        } catch {
            print("[PhotoStorage] Failed to save metadata: \(error)")
        }
    }
    
    func photosGroupedByDate() -> [(Date, [Photo])] {
        let grouped = Dictionary(grouping: photos) { photo in
            Calendar.current.startOfDay(for: photo.captureDate)
        }
        
        return grouped.sorted { $0.key > $1.key }
    }
    
    func hasPhoto(for date: Date) -> Bool {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        return photos.contains { photo in
            calendar.isDate(photo.captureDate, inSameDayAs: targetDay)
        }
    }
    
    func getPhotoID(for date: Date) -> String? {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        return photos.first { photo in
            calendar.isDate(photo.captureDate, inSameDayAs: targetDay)
        }?.id.uuidString
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