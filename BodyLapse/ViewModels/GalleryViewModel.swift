import Foundation
import SwiftUI

@MainActor
class GalleryViewModel: ObservableObject {
    @Published var photos: [Photo] = []
    @Published var videos: [Video] = []
    @Published var selectedSection: GallerySection = .photos
    @Published var selectedCategories: Set<String> = []
    @Published var sortOrder: SortOrder = .newest
    @Published var showingFilterOptions = false
    
    // 選択モードプロパティ
    @Published var isSelectionMode = false
    @Published var selectedPhotoIds: Set<String> = []
    @Published var selectedVideoIds: Set<String> = []
    
    // グリッド設定
    @Published var gridColumns: Int = 3 {
        didSet {
            // 設定を保存
            UserDefaults.standard.set(gridColumns, forKey: "galleryGridColumns")
        }
    }
    
    // 日付フィルタリング
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
        // 保存されたグリッド列数の設定を読み込み
        let savedColumns = UserDefaults.standard.integer(forKey: "galleryGridColumns")
        if savedColumns >= 2 && savedColumns <= 5 {
            gridColumns = savedColumns
        }
        loadData()
        
        // カテゴリー更新を監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCategoriesUpdated),
            name: Notification.Name("CategoriesUpdated"),
            object: nil
        )

        // 写真/データ更新（インポート・クラウド復元など）を監視して写真・動画を再読込
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDataUpdated),
            name: Notification.Name("PhotosUpdated"),
            object: nil
        )
    }

    @objc private func handleDataUpdated() {
        DispatchQueue.main.async { [weak self] in
            self?.loadData()
        }
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
    
    var filteredPhotos: [Photo] {
        var result = photos
        
        // カテゴリーフィルターを適用
        if !selectedCategories.isEmpty {
            result = result.filter { selectedCategories.contains($0.categoryId) }
        }
        
        // 日付フィルターを適用 (選んだ日を先に 0:00 に揃え、写真ごとに全部の日と比べない)
        if !selectedDates.isEmpty {
            let calendar = Calendar.current
            let days = Set(selectedDates.map { calendar.startOfDay(for: $0) })
            result = result.filter { days.contains(calendar.startOfDay(for: $0.captureDate)) }
        }
        
        // ソート順を適用
        switch sortOrder {
        case .newest:
            result.sort { $0.captureDate > $1.captureDate }
        case .oldest:
            result.sort { $0.captureDate < $1.captureDate }
        }
        
        return result
    }
    
    var availableCategories: [PhotoCategory] {
        CategoryStorageService.shared.getActiveCategories()
    }
    
    func photosGroupedByMonth() -> [MonthGroup<Photo>] {
        MonthGrouping.group(filteredPhotos, date: \.captureDate, newestFirst: sortOrder == .newest)
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
    
    func videosGroupedByMonth() -> [MonthGroup<Video>] {
        MonthGrouping.group(videos, date: \.createdDate, newestFirst: true)
    }
    
    // MARK: - 選択モードメソッド
    
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
    
    // MARK: - 一括操作
    
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
    
    // MARK: - 通知ハンドラー
    
    @objc private func handleCategoriesUpdated() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("GalleryViewModel: Received CategoriesUpdated notification")
            
            // カテゴリーが変更された可能性があるため写真を再読み込み
            self.loadPhotos()
            
            // 選択中のカテゴリーが利用不可になった場合フィルターをクリア
            let availableIds = self.availableCategories.map { $0.id }
            self.selectedCategories = self.selectedCategories.filter { availableIds.contains($0) }
            
            // UIを強制更新
            self.objectWillChange.send()
        }
    }
}
