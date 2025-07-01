import Foundation
import SwiftUI
import Photos

@MainActor
class GalleryViewModel: ObservableObject {
    @Published var photos: [Photo] = []
    @Published var videos: [Video] = []
    @Published var selectedSection: GallerySection = .videos
    @Published var selectedCategories: Set<String> = []
    @Published var sortOrder: SortOrder = .newest
    @Published var showingFilterOptions = false
    
    enum GallerySection: String, CaseIterable {
        case videos = "Videos"
        case photos = "Photos"
    }
    
    enum SortOrder: String, CaseIterable {
        case newest = "newest"
        case oldest = "oldest"
        
        var localizedString: String {
            switch self {
            case .newest: return "gallery.filter.newest".localized
            case .oldest: return "gallery.filter.oldest".localized
            }
        }
    }
    
    init() {
        loadData()
    }
    
    func loadData() {
        loadPhotos()
        loadVideos()
    }
    
    func loadPhotos() {
        photos = PhotoStorageService.shared.photos
    }
    
    func loadVideos() {
        VideoStorageService.shared.initialize()
        videos = VideoStorageService.shared.videos
    }
    
    func deletePhoto(_ photo: Photo) {
        do {
            try PhotoStorageService.shared.deletePhoto(photo)
            loadPhotos()
        } catch {
            print("Failed to delete photo: \(error)")
        }
    }
    
    func deleteVideo(_ video: Video) {
        do {
            try VideoStorageService.shared.deleteVideo(video)
            loadVideos()
        } catch {
            print("Failed to delete video: \(error)")
        }
    }
    
    func savePhotoToLibrary(_ photo: Photo, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                completion(false, NSError(domain: "GalleryViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied"]))
                return
            }
            
            guard let image = PhotoStorageService.shared.loadImage(for: photo) else {
                completion(false, NSError(domain: "GalleryViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"]))
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    completion(success, error)
                }
            }
        }
    }
    
    func saveVideoToLibrary(_ video: Video, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                completion(false, NSError(domain: "GalleryViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied"]))
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: video.fileURL)
            }) { success, error in
                DispatchQueue.main.async {
                    completion(success, error)
                }
            }
        }
    }
    
    var filteredPhotos: [Photo] {
        var result = photos
        
        // Apply category filter
        if !selectedCategories.isEmpty {
            result = result.filter { selectedCategories.contains($0.categoryId) }
        }
        
        // Apply sort order
        switch sortOrder {
        case .newest:
            result.sort { $0.captureDate > $1.captureDate }
        case .oldest:
            result.sort { $0.captureDate < $1.captureDate }
        }
        
        return result
    }
    
    var availableCategories: [PhotoCategory] {
        let isPremium = SubscriptionManagerService.shared.isPremium
        return CategoryStorageService.shared.getActiveCategoriesForUser(isPremium: isPremium)
    }
    
    func photosGroupedByMonth() -> [(String, [Photo])] {
        let grouped = Dictionary(grouping: filteredPhotos) { photo in
            formatMonthYear(from: photo.captureDate)
        }
        
        return grouped.sorted { lhs, rhs in
            guard let lhsDate = dateFromMonthYear(lhs.key),
                  let rhsDate = dateFromMonthYear(rhs.key) else {
                return false
            }
            
            // Sort months based on the current sort order
            switch sortOrder {
            case .newest:
                return lhsDate > rhsDate
            case .oldest:
                return lhsDate < rhsDate
            }
        }
    }
    
    func toggleCategory(_ categoryId: String) {
        if selectedCategories.contains(categoryId) {
            selectedCategories.remove(categoryId)
        } else {
            selectedCategories.insert(categoryId)
        }
    }
    
    func clearFilters() {
        selectedCategories.removeAll()
        sortOrder = .newest
    }
    
    func videosGroupedByMonth() -> [(String, [Video])] {
        let grouped = Dictionary(grouping: videos) { video in
            formatMonthYear(from: video.createdDate)
        }
        
        return grouped.sorted { lhs, rhs in
            guard let lhsDate = dateFromMonthYear(lhs.key),
                  let rhsDate = dateFromMonthYear(rhs.key) else {
                return false
            }
            return lhsDate > rhsDate
        }
    }
    
    private func formatMonthYear(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func dateFromMonthYear(_ monthYear: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.date(from: monthYear)
    }
}