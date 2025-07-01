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
        
        // Migrate existing photos to category structure
        migratePhotosToCategory()
    }
    
    private func createPhotosDirectoryIfNeeded() {
        guard let photosDirectory = photosDirectory else {
            // Error: Could not access photos directory
            return
        }
        
        do {
            try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
            
            // Create default category directory
            let defaultCategoryDir = photosDirectory.appendingPathComponent(PhotoCategory.defaultCategory.id)
            try FileManager.default.createDirectory(at: defaultCategoryDir, withIntermediateDirectories: true)
        } catch {
            // Error creating photos directory
        }
    }
    
    func savePhoto(_ image: UIImage, captureDate: Date = Date(), categoryId: String = PhotoCategory.defaultCategory.id, isFaceBlurred: Bool = false, bodyDetectionConfidence: Double? = nil, weight: Double? = nil, bodyFatPercentage: Double? = nil) throws -> Photo {
        guard let photosDirectory = photosDirectory else {
            throw PhotoStorageError.directoryAccessFailed
        }
        
        // Create category directory if needed
        let categoryDir = photosDirectory.appendingPathComponent(categoryId)
        if !FileManager.default.fileExists(atPath: categoryDir.path) {
            try FileManager.default.createDirectory(at: categoryDir, withIntermediateDirectories: true)
        }
        
        // Fix image orientation to ensure it's always saved in portrait
        let orientedImage = image.fixedOrientation()
        
        guard let imageData = orientedImage.jpegData(compressionQuality: 0.9) else {
            throw PhotoStorageError.compressionFailed
        }
        
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = categoryDir.appendingPathComponent(fileName)
        
        try imageData.write(to: fileURL)
        
        let photo = Photo(
            captureDate: captureDate,
            fileName: fileName,
            categoryId: categoryId,
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
    
    func hasPhotoForToday(categoryId: String = PhotoCategory.defaultCategory.id) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return photos.contains { photo in
            photo.categoryId == categoryId &&
            calendar.isDate(photo.captureDate, inSameDayAs: today)
        }
    }
    
    func hasAnyPhotoForToday() -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return photos.contains { photo in
            calendar.isDate(photo.captureDate, inSameDayAs: today)
        }
    }
    
    func getPhotoForDate(_ date: Date, categoryId: String? = nil) -> Photo? {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        return photos.first { photo in
            (categoryId == nil || photo.categoryId == categoryId) &&
            calendar.isDate(photo.captureDate, inSameDayAs: targetDay)
        }
    }
    
    func getPhotosForDate(_ date: Date) -> [Photo] {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        return photos.filter { photo in
            calendar.isDate(photo.captureDate, inSameDayAs: targetDay)
        }.sorted { $0.categoryId < $1.categoryId }
    }
    
    func replacePhoto(for date: Date, categoryId: String = PhotoCategory.defaultCategory.id, with image: UIImage, isFaceBlurred: Bool = false, bodyDetectionConfidence: Double? = nil, weight: Double? = nil, bodyFatPercentage: Double? = nil) throws -> Photo {
        // Replacing photo for date and category
        if let existingPhoto = getPhotoForDate(date, categoryId: categoryId) {
            // Found existing photo for date and category, deleting
            try deletePhoto(existingPhoto)
        }
        
        let newPhoto = try savePhoto(image, captureDate: date, categoryId: categoryId, isFaceBlurred: isFaceBlurred, bodyDetectionConfidence: bodyDetectionConfidence, weight: weight, bodyFatPercentage: bodyFatPercentage)
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
        
        let categoryDir = photosDirectory.appendingPathComponent(photo.categoryId)
        let fileURL = categoryDir.appendingPathComponent(photo.fileName)
        try FileManager.default.removeItem(at: fileURL)
        
        photos.removeAll { $0.id == photo.id }
        savePhotosMetadata()
    }
    
    func loadImage(for photo: Photo) -> UIImage? {
        guard let photosDirectory = photosDirectory else {
            // Error: Could not access photos directory
            return nil
        }
        
        let categoryDir = photosDirectory.appendingPathComponent(photo.categoryId)
        let fileURL = categoryDir.appendingPathComponent(photo.fileName)
        
        // Try new path first
        if let imageData = try? Data(contentsOf: fileURL) {
            return UIImage(data: imageData)
        }
        
        // Fallback to old path for backward compatibility
        let oldFileURL = photosDirectory.appendingPathComponent(photo.fileName)
        guard let imageData = try? Data(contentsOf: oldFileURL) else { return nil }
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
            for (_, _) in photos.prefix(3).enumerated() {
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
    
    func hasPhoto(for date: Date, categoryId: String? = nil) -> Bool {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        return photos.contains { photo in
            (categoryId == nil || photo.categoryId == categoryId) &&
            calendar.isDate(photo.captureDate, inSameDayAs: targetDay)
        }
    }
    
    func getPhotoID(for date: Date, categoryId: String? = nil) -> String? {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        return photos.first { photo in
            (categoryId == nil || photo.categoryId == categoryId) &&
            calendar.isDate(photo.captureDate, inSameDayAs: targetDay)
        }?.id.uuidString
    }
    
    // MARK: - Category Support Methods
    
    func getPhotosForCategory(_ categoryId: String) -> [Photo] {
        return photos.filter { $0.categoryId == categoryId }
            .sorted { $0.captureDate > $1.captureDate }
    }
    
    func getPhotoCategories(for date: Date) -> [String] {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        return photos.filter { photo in
            calendar.isDate(photo.captureDate, inSameDayAs: targetDay)
        }.map { $0.categoryId }.uniqued()
    }
    
    func photosGroupedByDateAndCategory() -> [(Date, [(String, [Photo])])] {
        let calendar = Calendar.current
        
        // Group by date first
        let dateGrouped = Dictionary(grouping: photos) { photo in
            calendar.startOfDay(for: photo.captureDate)
        }
        
        // Then group by category within each date
        let result = dateGrouped.map { (date, photosForDate) in
            let categoryGrouped = Dictionary(grouping: photosForDate) { $0.categoryId }
                .sorted { $0.key < $1.key }
                .map { ($0.key, $0.value.sorted { $0.captureDate > $1.captureDate }) }
            
            return (date, categoryGrouped)
        }
        
        return result.sorted { $0.0 > $1.0 }
    }
    
    func getPhotoDatesForCategory(_ categoryId: String) -> [Date] {
        let calendar = Calendar.current
        let photosInCategory = photos.filter { $0.categoryId == categoryId }
        
        let dates = Set(photosInCategory.map { calendar.startOfDay(for: $0.captureDate) })
        return Array(dates).sorted(by: >)
    }
    
    func migratePhotosToCategory(_ categoryId: String = PhotoCategory.defaultCategory.id) {
        // For migrating existing photos without categoryId
        var needsSave = false
        
        for (_, photo) in photos.enumerated() {
            // Photos loaded from old format won't have categoryId set properly
            // This will be handled by the Photo's init(from decoder:) method
            // but we need to move files to new location
            
            guard let photosDirectory = photosDirectory else { continue }
            
            let oldPath = photosDirectory.appendingPathComponent(photo.fileName)
            let categoryDir = photosDirectory.appendingPathComponent(photo.categoryId)
            let newPath = categoryDir.appendingPathComponent(photo.fileName)
            
            if FileManager.default.fileExists(atPath: oldPath.path) &&
               !FileManager.default.fileExists(atPath: newPath.path) {
                do {
                    // Create category directory if needed
                    if !FileManager.default.fileExists(atPath: categoryDir.path) {
                        try FileManager.default.createDirectory(at: categoryDir, withIntermediateDirectories: true)
                    }
                    
                    // Move file to new location
                    try FileManager.default.moveItem(at: oldPath, to: newPath)
                    needsSave = true
                    print("Migrated photo \(photo.fileName) to category \(photo.categoryId)")
                } catch {
                    print("Failed to migrate photo \(photo.fileName): \(error)")
                }
            }
        }
        
        if needsSave {
            savePhotosMetadata()
        }
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
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