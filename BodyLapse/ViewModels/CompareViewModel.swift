import Foundation
import SwiftUI

class CompareViewModel: ObservableObject {
    @Published var photos: [Photo] = []
    
    init() {
        loadPhotos()
    }
    
    func loadPhotos() {
        // Force reload metadata from disk to get latest weight/body fat data
        PhotoStorageService.shared.reloadPhotosFromDisk()
        
        // Sync weight data from WeightStorageService
        Task { @MainActor in
            // First sync weight data in PhotoStorageService
            await PhotoStorageService.shared.syncWeightData()
            
            // Then load the synced photos
            photos = PhotoStorageService.shared.photos.sorted { $0.captureDate > $1.captureDate }
            print("[CompareViewModel] Loaded \(photos.count) photos from PhotoStorageService")
            
            // Also do local sync to ensure everything is up to date
            do {
                let weightEntries = try await WeightStorageService.shared.loadEntries()
                syncWeightDataToPhotos(weightEntries)
            } catch {
                print("[CompareViewModel] Failed to load weight entries: \(error)")
            }
        }
    }
    
    private func syncWeightDataToPhotos(_ weightEntries: [WeightEntry]) {
        print("[CompareViewModel] Syncing weight data from \(weightEntries.count) weight entries")
        
        for entry in weightEntries {
            // Find ALL photos for the same date (not just the first one)
            let photosForDate = photos.enumerated().compactMap { (index, photo) in
                Calendar.current.isDate(photo.captureDate, inSameDayAs: entry.date) ? index : nil
            }
            
            if photosForDate.isEmpty {
                print("[CompareViewModel] No photo found for weight entry date: \(entry.date)")
                continue
            }
            
            print("[CompareViewModel] Found \(photosForDate.count) photos for date \(entry.date)")
            
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
                    print("[CompareViewModel] Synced weight=\(entry.weight), bodyFat=\(entry.bodyFatPercentage ?? -1) to photo id=\(updatedPhoto.id), category=\(updatedPhoto.categoryId)")
                    
                    // Also update in PhotoStorageService to persist the change
                    PhotoStorageService.shared.updatePhotoMetadata(updatedPhoto, weight: updatedPhoto.weight, bodyFatPercentage: updatedPhoto.bodyFatPercentage)
                }
            }
        }
        
        // Re-sort after updates
        photos = photos.sorted { $0.captureDate > $1.captureDate }
        
        // Debug: Print updated photos
        print("[CompareViewModel] After sync - First 5 photos:")
        for (index, photo) in photos.prefix(5).enumerated() {
            print("  Photo \(index): date=\(photo.captureDate), weight=\(photo.weight ?? -1), bodyFat=\(photo.bodyFatPercentage ?? -1)")
        }
    }
    
    func getDaysBetween(_ firstPhoto: Photo, _ secondPhoto: Photo) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: firstPhoto.captureDate, to: secondPhoto.captureDate)
        return abs(components.day ?? 0)
    }
    
    func getWeightDifference(_ firstPhoto: Photo, _ secondPhoto: Photo) -> Double? {
        guard let firstWeight = firstPhoto.weight,
              let secondWeight = secondPhoto.weight else {
            return nil
        }
        return secondWeight - firstWeight
    }
    
    func getBodyFatDifference(_ firstPhoto: Photo, _ secondPhoto: Photo) -> Double? {
        guard let firstBodyFat = firstPhoto.bodyFatPercentage,
              let secondBodyFat = secondPhoto.bodyFatPercentage else {
            return nil
        }
        return secondBodyFat - firstBodyFat
    }
}