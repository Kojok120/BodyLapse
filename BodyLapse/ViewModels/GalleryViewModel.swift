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
    
    // Selection mode properties
    @Published var isSelectionMode = false
    @Published var selectedPhotoIds: Set<String> = []
    @Published var selectedVideoIds: Set<String> = []
    
    // Grid configuration
    @Published var gridColumns: Int = 3 {
        didSet {
            // Save preference
            UserDefaults.standard.set(gridColumns, forKey: "galleryGridColumns")
        }
    }
    
    // Date filtering
    @Published var selectedDates: Set<Date> = []
    @Published var showingDatePicker = false
    
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
        // Load saved grid columns preference
        let savedColumns = UserDefaults.standard.integer(forKey: "galleryGridColumns")
        if savedColumns >= 2 && savedColumns <= 5 {
            gridColumns = savedColumns
        }
        loadData()
        
        // Listen for category updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCategoriesUpdated),
            name: Notification.Name("CategoriesUpdated"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
        
        // Apply date filter
        if !selectedDates.isEmpty {
            result = result.filter { photo in
                let calendar = Calendar.current
                return selectedDates.contains { date in
                    calendar.isDate(photo.captureDate, inSameDayAs: date)
                }
            }
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
        selectedDates.removeAll()
        sortOrder = .newest
    }
    
    func toggleDate(_ date: Date) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        if selectedDates.contains(where: { calendar.isDate($0, inSameDayAs: normalizedDate) }) {
            selectedDates = selectedDates.filter { !calendar.isDate($0, inSameDayAs: normalizedDate) }
        } else {
            selectedDates.insert(normalizedDate)
        }
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
    
    // MARK: - Selection Mode Methods
    
    func enterSelectionMode() {
        isSelectionMode = true
        selectedPhotoIds.removeAll()
        selectedVideoIds.removeAll()
    }
    
    func exitSelectionMode() {
        isSelectionMode = false
        selectedPhotoIds.removeAll()
        selectedVideoIds.removeAll()
    }
    
    func togglePhotoSelection(_ photoId: String) {
        if selectedPhotoIds.contains(photoId) {
            selectedPhotoIds.remove(photoId)
        } else {
            selectedPhotoIds.insert(photoId)
        }
    }
    
    func toggleVideoSelection(_ videoId: String) {
        if selectedVideoIds.contains(videoId) {
            selectedVideoIds.remove(videoId)
        } else {
            selectedVideoIds.insert(videoId)
        }
    }
    
    func selectAllPhotos() {
        selectedPhotoIds = Set(filteredPhotos.map { $0.id.uuidString })
    }
    
    func selectAllVideos() {
        selectedVideoIds = Set(videos.map { $0.id.uuidString })
    }
    
    func clearSelection() {
        selectedPhotoIds.removeAll()
        selectedVideoIds.removeAll()
    }
    
    var hasSelection: Bool {
        !selectedPhotoIds.isEmpty || !selectedVideoIds.isEmpty
    }
    
    var selectionCount: Int {
        selectedSection == .photos ? selectedPhotoIds.count : selectedVideoIds.count
    }
    
    // MARK: - Bulk Operations
    
    func bulkDeletePhotos() {
        let photosToDelete = photos.filter { selectedPhotoIds.contains($0.id.uuidString) }
        for photo in photosToDelete {
            deletePhoto(photo)
        }
        exitSelectionMode()
    }
    
    func bulkDeleteVideos() {
        let videosToDelete = videos.filter { selectedVideoIds.contains($0.id.uuidString) }
        for video in videosToDelete {
            deleteVideo(video)
        }
        exitSelectionMode()
    }
    
    func bulkSavePhotosToLibrary(completion: @escaping (Bool, Error?) -> Void) {
        let photosToSave = photos.filter { selectedPhotoIds.contains($0.id.uuidString) }
        let group = DispatchGroup()
        var hasError = false
        var lastError: Error?
        
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                completion(false, NSError(domain: "GalleryViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied"]))
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                for photo in photosToSave {
                    group.enter()
                    if let image = PhotoStorageService.shared.loadImage(for: photo) {
                        PHAssetChangeRequest.creationRequestForAsset(from: image)
                    }
                    group.leave()
                }
            }) { success, error in
                if !success {
                    hasError = true
                    lastError = error
                }
                
                DispatchQueue.main.async {
                    completion(!hasError, lastError)
                    self.exitSelectionMode()
                }
            }
        }
    }
    
    func bulkSaveVideosToLibrary(completion: @escaping (Bool, Error?) -> Void) {
        let videosToSave = videos.filter { selectedVideoIds.contains($0.id.uuidString) }
        let group = DispatchGroup()
        var hasError = false
        var lastError: Error?
        
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                completion(false, NSError(domain: "GalleryViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied"]))
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                for video in videosToSave {
                    group.enter()
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: video.fileURL)
                    group.leave()
                }
            }) { success, error in
                if !success {
                    hasError = true
                    lastError = error
                }
                
                DispatchQueue.main.async {
                    completion(!hasError, lastError)
                    self.exitSelectionMode()
                }
            }
        }
    }
    
    func getSelectedPhotosForSharing() -> [UIImage] {
        let selectedPhotos = photos.filter { selectedPhotoIds.contains($0.id.uuidString) }
        return selectedPhotos.compactMap { PhotoStorageService.shared.loadImage(for: $0) }
    }
    
    func getSelectedVideosForSharing() -> [URL] {
        let selectedVideos = videos.filter { selectedVideoIds.contains($0.id.uuidString) }
        return selectedVideos.map { $0.fileURL }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleCategoriesUpdated() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("GalleryViewModel: Received CategoriesUpdated notification")
            
            // Reload photos as categories might have changed
            self.loadPhotos()
            
            // Clear category filters if any selected categories are no longer available
            let availableIds = self.availableCategories.map { $0.id }
            self.selectedCategories = self.selectedCategories.filter { availableIds.contains($0) }
            
            // Force UI update
            self.objectWillChange.send()
        }
    }
}