import Foundation
import UIKit
import StoreKit

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
        
        // If weight/bodyFat not provided, check if there's existing weight data for this date from other photos
        var finalWeight = weight
        var finalBodyFat = bodyFatPercentage
        
        if finalWeight == nil || finalBodyFat == nil {
            // Check if any other photo on this date has weight data
            let photosOnSameDate = photos.filter { photo in
                Calendar.current.isDate(photo.captureDate, inSameDayAs: captureDate)
            }
            
            for photo in photosOnSameDate {
                if finalWeight == nil, let photoWeight = photo.weight {
                    finalWeight = photoWeight
                }
                if finalBodyFat == nil, let photoBodyFat = photo.bodyFatPercentage {
                    finalBodyFat = photoBodyFat
                }
                if finalWeight != nil && finalBodyFat != nil {
                    break
                }
            }
        }
        
        let photo = Photo(
            captureDate: captureDate,
            fileName: fileName,
            categoryId: categoryId,
            isFaceBlurred: isFaceBlurred,
            bodyDetectionConfidence: bodyDetectionConfidence,
            weight: finalWeight,
            bodyFatPercentage: finalBodyFat
        )
        
        // Created photo with metadata
        
        photos.append(photo)
        photos.sort { $0.captureDate > $1.captureDate }
        
        // If this photo has weight/body fat data, update all other photos on the same date
        if finalWeight != nil || finalBodyFat != nil {
            let photosOnSameDate = photos.enumerated().compactMap { (index, p) in
                Calendar.current.isDate(p.captureDate, inSameDayAs: captureDate) && p.id != photo.id ? index : nil
            }
            
            for photoIndex in photosOnSameDate {
                var updatedPhoto = photos[photoIndex]
                if let w = finalWeight {
                    updatedPhoto.weight = w
                }
                if let bf = finalBodyFat {
                    updatedPhoto.bodyFatPercentage = bf
                }
                photos[photoIndex] = updatedPhoto
            }
        }
        
        savePhotosMetadata()
        
        // Photo saved to metadata
        
        // Post notification that photos have been updated
        NotificationCenter.default.post(
            name: Notification.Name("PhotosUpdated"),
            object: nil,
            userInfo: ["photo": photo]
        )
        
        // Check if we should request app review
        checkAndRequestReviewIfNeeded()
        
        return photo
    }
    
    func photoExists(for dateString: String, categoryId: String) -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = dateFormatter.date(from: dateString) else { return false }
        
        let calendar = Calendar.current
        return photos.contains { photo in
            calendar.isDate(photo.captureDate, inSameDayAs: date) && photo.categoryId == categoryId
        }
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
    
    func hasPhotoForDate(_ date: Date, categoryId: String = PhotoCategory.defaultCategory.id) -> Bool {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        return photos.contains { photo in
            photo.categoryId == categoryId &&
            calendar.isDate(photo.captureDate, inSameDayAs: targetDay)
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
        
        // If weight/bodyFat not provided, check existing photo for this date/category
        var finalWeight = weight
        var finalBodyFat = bodyFatPercentage
        
        if let existingPhoto = getPhotoForDate(date, categoryId: categoryId) {
            // Use existing weight/body fat if not provided
            if finalWeight == nil {
                finalWeight = existingPhoto.weight
            }
            if finalBodyFat == nil {
                finalBodyFat = existingPhoto.bodyFatPercentage
            }
            
            // Found existing photo for date and category, deleting
            try deletePhoto(existingPhoto)
        }
        
        let newPhoto = try savePhoto(image, captureDate: date, categoryId: categoryId, isFaceBlurred: isFaceBlurred, bodyDetectionConfidence: bodyDetectionConfidence, weight: finalWeight, bodyFatPercentage: finalBodyFat)
        // New photo saved
        return newPhoto
    }
    
    func updatePhotoMetadata(_ photo: Photo, weight: Double?, bodyFatPercentage: Double?) {
        guard let index = photos.firstIndex(where: { $0.id == photo.id }) else {
            // Photo not found for update
            return
        }
        
        var updatedPhoto = photos[index]  // Use the photo from the array, not the parameter
        updatedPhoto.weight = weight
        updatedPhoto.bodyFatPercentage = bodyFatPercentage
        
        // Updating photo metadata
        
        photos[index] = updatedPhoto
        
        // Also update all other photos on the same date with the same weight/body fat
        let photosOnSameDate = photos.enumerated().compactMap { (idx, p) in
            Calendar.current.isDate(p.captureDate, inSameDayAs: updatedPhoto.captureDate) && p.id != updatedPhoto.id ? idx : nil
        }
        
        for photoIndex in photosOnSameDate {
            var otherPhoto = photos[photoIndex]
            otherPhoto.weight = weight
            otherPhoto.bodyFatPercentage = bodyFatPercentage
            photos[photoIndex] = otherPhoto
        }
        
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
            
            // Sync weight data from WeightStorageService immediately
            Task {
                await syncWeightDataFromStorage()
                
                // Post notification that sync is complete
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: Notification.Name("WeightDataSyncComplete"),
                        object: nil
                    )
                }
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
    
    // MARK: - App Rating Support
    
    func getCumulativePhotoDays() -> Int {
        let calendar = Calendar.current
        let uniqueDates = Set(photos.map { calendar.startOfDay(for: $0.captureDate) })
        return uniqueDates.count
    }
    
    func checkAndRequestReviewIfNeeded() {
        Task { @MainActor in
            let userSettings = UserSettingsManager.shared
            
            // Skip if user has already rated the app
            if userSettings.settings.hasRatedApp {
                return
            }
            
            let cumulativeDays = getCumulativePhotoDays()
            
            // Check if cumulative days is a multiple of 30 (but not 0)
            if cumulativeDays > 0 && cumulativeDays % 30 == 0 {
                // Request review
                if let windowScene = UIApplication.shared.connectedScenes
                    .filter({ $0.activationState == .foregroundActive })
                    .first as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: windowScene)
                    
                    // Mark as rated to avoid showing again
                    userSettings.settings.hasRatedApp = true
                }
            }
        }
    }
    
    // MARK: - Weight Data Sync
    
    func syncWeightData() async {
        await syncWeightDataFromStorage()
    }
    
    private func syncWeightDataFromStorage() async {
        do {
            let weightEntries = try await WeightStorageService.shared.loadEntries()
            print("[PhotoStorage] Syncing weight data from \(weightEntries.count) weight entries")
            
            for entry in weightEntries {
                // Find ALL photos for the same date (not just the first one)
                let photosForDate = photos.enumerated().compactMap { (index, photo) in
                    Calendar.current.isDate(photo.captureDate, inSameDayAs: entry.date) ? index : nil
                }
                
                if photosForDate.isEmpty {
                    continue
                }
                
                // Update ALL photos for this date
                for photoIndex in photosForDate {
                    var updatedPhoto = photos[photoIndex]
                    var needsUpdate = false
                    
                    // Always sync weight data from WeightEntry if it exists
                    if entry.weight > 0 && updatedPhoto.weight != entry.weight {
                        updatedPhoto.weight = entry.weight
                        needsUpdate = true
                    }
                    
                    // Always sync body fat data from WeightEntry if it exists
                    if let bodyFat = entry.bodyFatPercentage, updatedPhoto.bodyFatPercentage != bodyFat {
                        updatedPhoto.bodyFatPercentage = bodyFat
                        needsUpdate = true
                    }
                    
                    if needsUpdate {
                        photos[photoIndex] = updatedPhoto
                        print("[PhotoStorage] Synced weight=\(entry.weight), bodyFat=\(entry.bodyFatPercentage ?? -1) to photo id=\(updatedPhoto.id)")
                    }
                }
            }
            
            // Save updated metadata
            savePhotosMetadata()
        } catch {
            print("[PhotoStorage] Failed to sync weight data: \(error)")
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