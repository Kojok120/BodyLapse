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
        print("[PhotoStorage] Initializing...")
        createPhotosDirectoryIfNeeded()
        loadPhotosMetadata()
        print("[PhotoStorage] Initialized with \(photos.count) photos")
    }
    
    private func createPhotosDirectoryIfNeeded() {
        guard let photosDirectory = photosDirectory else {
            print("[PhotoStorage] Error: Could not access photos directory")
            return
        }
        
        do {
            try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        } catch {
            print("[PhotoStorage] Error creating photos directory: \(error)")
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
        
        print("[PhotoStorage] Created photo - weight: \(weight ?? -1), bodyFat: \(bodyFatPercentage ?? -1)")
        
        photos.append(photo)
        photos.sort { $0.captureDate > $1.captureDate }
        
        savePhotosMetadata()
        
        print("[PhotoStorage] Photo saved to metadata - total photos: \(photos.count)")
        
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
        guard let index = photos.firstIndex(where: { $0.id == photo.id }) else {
            print("[PhotoStorage] updatePhotoMetadata - Photo not found for id: \(photo.id)")
            return
        }
        
        var updatedPhoto = photo
        updatedPhoto.weight = weight
        updatedPhoto.bodyFatPercentage = bodyFatPercentage
        
        print("[PhotoStorage] updatePhotoMetadata - Updating photo date: \(photo.captureDate), weight: \(weight ?? -1) -> \(updatedPhoto.weight ?? -1), bodyFat: \(bodyFatPercentage ?? -1) -> \(updatedPhoto.bodyFatPercentage ?? -1)")
        
        photos[index] = updatedPhoto
        savePhotosMetadata()
        
        print("[PhotoStorage] updatePhotoMetadata - Successfully updated and saved metadata")
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
            print("[PhotoStorage] Error: Could not access photos directory")
            return nil
        }
        
        let fileURL = photosDirectory.appendingPathComponent(photo.fileName)
        guard let imageData = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: imageData)
    }
    
    func reloadPhotosFromDisk() {
        print("[PhotoStorage] Reloading photos metadata from disk")
        loadPhotosMetadata()
    }
    
    private func loadPhotosMetadata() {
        guard let metadataURL = metadataURL else {
            print("[PhotoStorage] Error: Could not access metadata URL")
            photos = []
            return
        }
        
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
            
            // Debug: Print first few photos with weight data
            for (index, photo) in photos.prefix(3).enumerated() {
                print("[PhotoStorage] Photo \(index): date=\(photo.captureDate), weight=\(photo.weight ?? -1), bodyFat=\(photo.bodyFatPercentage ?? -1)")
            }
        } catch {
            print("[PhotoStorage] Failed to decode metadata: \(error)")
            photos = []
        }
    }
    
    private func savePhotosMetadata() {
        guard let metadataURL = metadataURL else {
            print("[PhotoStorage] Error: Could not access metadata URL")
            return
        }
        
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