import Foundation
import UIKit

class PhotoStorageService {
    static let shared = PhotoStorageService()
    
    private init() {}
    
    var documentsDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    private var photosDirectory: URL? {
        documentsDirectory?.appendingPathComponent("Photos")
    }
    
    private var metadataURL: URL? {
        documentsDirectory?.appendingPathComponent("photos_metadata.json")
    }
    
    private(set) var photos: [Photo] = []
    
    func initialize() {
        // Initializing...
        createPhotosDirectoryIfNeeded()
        loadPhotosMetadata()
        // Initialized with photos
    }
    
    private func createPhotosDirectoryIfNeeded() {
        guard let photosDirectory = photosDirectory else {
            // Error: Could not access photos directory
            return
        }
        
        do {
            try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        } catch {
            // Error creating photos directory
        }
    }
    
    func savePhoto(_ image: UIImage, captureDate: Date = Date(), isFaceBlurred: Bool = false, bodyDetectionConfidence: Double? = nil, weight: Double? = nil, bodyFatPercentage: Double? = nil) throws -> Photo {
        guard let photosDirectory = photosDirectory else {
            throw PhotoStorageError.directoryAccessFailed
        }
        
        // Fix image orientation to ensure it's always saved in portrait
        let orientedImage = image.fixedOrientation()
        
        guard let imageData = orientedImage.jpegData(compressionQuality: 0.9) else {
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
        
        // Created photo with metadata
        
        photos.append(photo)
        photos.sort { $0.captureDate > $1.captureDate }
        
        savePhotosMetadata()
        
        // Photo saved to metadata
        
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
        // Replacing photo for date
        if let existingPhoto = getPhotoForDate(date) {
            // Found existing photo for date, deleting
            try deletePhoto(existingPhoto)
        }
        
        let newPhoto = try savePhoto(image, captureDate: date, isFaceBlurred: isFaceBlurred, bodyDetectionConfidence: bodyDetectionConfidence, weight: weight, bodyFatPercentage: bodyFatPercentage)
        // New photo saved
        return newPhoto
    }
    
    func updatePhotoMetadata(_ photo: Photo, weight: Double?, bodyFatPercentage: Double?) {
        guard let index = photos.firstIndex(where: { $0.id == photo.id }) else {
            // Photo not found for update
            return
        }
        
        var updatedPhoto = photo
        updatedPhoto.weight = weight
        updatedPhoto.bodyFatPercentage = bodyFatPercentage
        
        // Updating photo metadata
        
        photos[index] = updatedPhoto
        savePhotosMetadata()
        
        // Successfully updated metadata
    }
    
    func deletePhoto(_ photo: Photo) throws {
        guard let photosDirectory = photosDirectory else {
            throw PhotoStorageError.directoryAccessFailed
        }
        
        let fileURL = photosDirectory.appendingPathComponent(photo.fileName)
        try FileManager.default.removeItem(at: fileURL)
        
        photos.removeAll { $0.id == photo.id }
        savePhotosMetadata()
    }
    
    func loadImage(for photo: Photo) -> UIImage? {
        guard let photosDirectory = photosDirectory else {
            // Error: Could not access photos directory
            return nil
        }
        
        let fileURL = photosDirectory.appendingPathComponent(photo.fileName)
        guard let imageData = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: imageData)
    }
    
    func reloadPhotosFromDisk() {
        // Reloading photos metadata from disk
        loadPhotosMetadata()
    }
    
    private func loadPhotosMetadata() {
        guard let metadataURL = metadataURL else {
            // Error: Could not access metadata URL
            photos = []
            return
        }
        
        // Loading metadata from disk
        
        guard let data = try? Data(contentsOf: metadataURL) else {
            // No metadata file found
            photos = []
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode([Photo].self, from: data)
            photos = decoded.sorted { $0.captureDate > $1.captureDate }
            // Loaded photos from metadata
            
            // Debug: Print first few photos with weight data
            for (index, photo) in photos.prefix(3).enumerated() {
                // Photo loaded from metadata
            }
        } catch {
            // Failed to decode metadata
            photos = []
        }
    }
    
    private func savePhotosMetadata() {
        guard let metadataURL = metadataURL else {
            // Error: Could not access metadata URL
            return
        }
        
        do {
            let encoded = try JSONEncoder().encode(photos)
            try encoded.write(to: metadataURL)
            // Saved metadata
        } catch {
            // Failed to save metadata
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
    case directoryAccessFailed
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress the image"
        case .saveFailed:
            return "Failed to save the photo"
        case .directoryAccessFailed:
            return "Failed to access the documents directory"
        }
    }
}