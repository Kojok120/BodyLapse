import Foundation
import UIKit
import StoreKit
import ImageIO

class PhotoStorageService {
    static let shared = PhotoStorageService()

    private let imageCache = NSCache<NSString, UIImage>()

    private init() {
        // 大まかな制限: キャッシュピクセルデータ約200MB（1ピクセル4バイト）
        imageCache.totalCostLimit = 200 * 1024 * 1024
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
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
        
        // 既存の写真をカテゴリ構造に移行
        migratePhotosToCategory()
    }
    
    private func createPhotosDirectoryIfNeeded() {
        guard let photosDirectory = photosDirectory else {
            // エラー: 写真ディレクトリにアクセスできません
            return
        }
        
        do {
            try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
            
            // デフォルトカテゴリディレクトリを作成
            let defaultCategoryDir = photosDirectory.appendingPathComponent(PhotoCategory.defaultCategory.id)
            try FileManager.default.createDirectory(at: defaultCategoryDir, withIntermediateDirectories: true)
        } catch {
            // 写真ディレクトリの作成エラー
        }
    }
    
    func savePhoto(_ image: UIImage, captureDate: Date = Date(), categoryId: String = PhotoCategory.defaultCategory.id, isFaceBlurred: Bool = false, bodyDetectionConfidence: Double? = nil, weight: Double? = nil, bodyFatPercentage: Double? = nil) throws -> Photo {
        guard let photosDirectory = photosDirectory else {
            throw PhotoStorageError.directoryAccessFailed
        }
        
        // 必要に応じてカテゴリディレクトリを作成
        let categoryDir = photosDirectory.appendingPathComponent(categoryId)
        if !FileManager.default.fileExists(atPath: categoryDir.path) {
            try FileManager.default.createDirectory(at: categoryDir, withIntermediateDirectories: true)
        }
        
        // 画像の向きを修正して常に縦向きで保存されるようにする
        let orientedImage = image.fixedOrientation()
        
        guard let imageData = orientedImage.jpegData(compressionQuality: 0.9) else {
            throw PhotoStorageError.compressionFailed
        }
        
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = categoryDir.appendingPathComponent(fileName)
        
        try imageData.write(to: fileURL)
        
        // 体重/体脂肪が未提供の場合、同日の他の写真から既存の体重データを確認
        var finalWeight = weight
        var finalBodyFat = bodyFatPercentage
        
        if finalWeight == nil || finalBodyFat == nil {
            // 同日の他の写真に体重データがあるか確認
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
        
        // メタデータ付きで写真を作成
        
        photos.append(photo)
        photos.sort { $0.captureDate > $1.captureDate }
        
        // この写真に体重/体脂肪データがある場合、同日の他の写真も更新
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
        
        // 写真をメタデータに保存
        
        // 写真が更新されたことを通知
        NotificationCenter.default.post(
            name: Notification.Name("PhotosUpdated"),
            object: nil,
            userInfo: ["photo": photo]
        )
        
        // アプリレビューをリクエストすべきか確認
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
        // 日付とカテゴリの写真を置換
        
        // 体重/体脂肪が未提供の場合、この日付/カテゴリの既存写真を確認
        var finalWeight = weight
        var finalBodyFat = bodyFatPercentage
        
        if let existingPhoto = getPhotoForDate(date, categoryId: categoryId) {
            // 未提供の場合は既存の体重/体脂肪を使用
            if finalWeight == nil {
                finalWeight = existingPhoto.weight
            }
            if finalBodyFat == nil {
                finalBodyFat = existingPhoto.bodyFatPercentage
            }
            
            // 日付とカテゴリの既存写真を検出、削除
            try deletePhoto(existingPhoto)
        }
        
        let newPhoto = try savePhoto(image, captureDate: date, categoryId: categoryId, isFaceBlurred: isFaceBlurred, bodyDetectionConfidence: bodyDetectionConfidence, weight: finalWeight, bodyFatPercentage: finalBodyFat)
        // 新しい写真を保存
        return newPhoto
    }
    
    func updatePhotoMetadata(_ photo: Photo, weight: Double?, bodyFatPercentage: Double?) {
        guard let index = photos.firstIndex(where: { $0.id == photo.id }) else {
            // 更新対象の写真が見つかりません
            return
        }
        
        var hasChanges = false
        var updatedPhoto = photos[index]  // Use the photo from the array, not the parameter
        if updatedPhoto.weight != weight {
            updatedPhoto.weight = weight
            hasChanges = true
        }
        if updatedPhoto.bodyFatPercentage != bodyFatPercentage {
            updatedPhoto.bodyFatPercentage = bodyFatPercentage
            hasChanges = true
        }
        
        // 写真メタデータを更新
        
        photos[index] = updatedPhoto
        
        // 同日の他の写真も同じ体重/体脂肪で更新
        let photosOnSameDate = photos.enumerated().compactMap { (idx, p) in
            Calendar.current.isDate(p.captureDate, inSameDayAs: updatedPhoto.captureDate) && p.id != updatedPhoto.id ? idx : nil
        }
        
        for photoIndex in photosOnSameDate {
            var otherPhoto = photos[photoIndex]
            var updated = false
            if otherPhoto.weight != weight {
                otherPhoto.weight = weight
                updated = true
            }
            if otherPhoto.bodyFatPercentage != bodyFatPercentage {
                otherPhoto.bodyFatPercentage = bodyFatPercentage
                updated = true
            }
            if updated {
                photos[photoIndex] = otherPhoto
                hasChanges = true
            }
        }
        
        guard hasChanges else { return }
        savePhotosMetadata()
        
        // メタデータの更新に成功
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
    
    func loadImage(for photo: Photo, targetSize: CGSize? = nil, scale: CGFloat = UIScreen.main.scale) -> UIImage? {
        guard let imageURL = imageURL(for: photo) else {
            // エラー: 写真ディレクトリにアクセスできません
            return nil
        }

        let cacheKey = cacheKey(for: photo, targetSize: targetSize, scale: scale)
        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }

        if let targetSize = targetSize,
           targetSize.width > 0,
           targetSize.height > 0,
           let downsampled = downsampleImage(at: imageURL, to: targetSize, scale: scale) {
            imageCache.setObject(downsampled, forKey: cacheKey, cost: downsampled.cacheCost)
            return downsampled
        }

        guard let imageData = try? Data(contentsOf: imageURL),
              let image = UIImage(data: imageData, scale: scale) else {
            return nil
        }
        imageCache.setObject(image, forKey: cacheKey, cost: image.cacheCost)
        return image
    }
    
    func reloadPhotosFromDisk(syncWeightData: Bool = true) {
        // ディスクから写真メタデータを再読み込み
        imageCache.removeAllObjects()
        loadPhotosMetadata(syncWeightData: syncWeightData)
    }
    
    private func loadPhotosMetadata(syncWeightData: Bool = true) {
        guard let metadataURL = metadataURL else {
            // エラー: メタデータURLにアクセスできません
            photos = []
            return
        }
        
        // ディスクからメタデータを読み込み
        
        guard let data = try? Data(contentsOf: metadataURL) else {
            // メタデータファイルが見つかりません
            photos = []
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode([Photo].self, from: data)
            photos = decoded.sorted { $0.captureDate > $1.captureDate }
            // メタデータから写真を読み込み済み
            
            if syncWeightData {
                // WeightStorageServiceから体重データを即座に同期
                Task { @MainActor in
                    await syncWeightDataFromStorage()
                    
                    // 同期完了通知を送信
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: Notification.Name("WeightDataSyncComplete"),
                            object: nil
                        )
                    }
                }
            }
        } catch {
            // メタデータのデコードに失敗
            photos = []
        }
    }
    
    private func savePhotosMetadata() {
        guard let metadataURL = metadataURL else {
            // エラー: メタデータURLにアクセスできません
            return
        }

        do {
            let encoded = try JSONEncoder().encode(photos)
            try encoded.write(to: metadataURL)
            // メタデータを保存済み
        } catch {
            // メタデータの保存に失敗
        }
    }

    private func imageURL(for photo: Photo) -> URL? {
        guard let photosDirectory = photosDirectory else { return nil }
        let categoryDir = photosDirectory.appendingPathComponent(photo.categoryId)
        let newURL = categoryDir.appendingPathComponent(photo.fileName)
        if FileManager.default.fileExists(atPath: newURL.path) {
            return newURL
        }
        let legacyURL = photosDirectory.appendingPathComponent(photo.fileName)
        if FileManager.default.fileExists(atPath: legacyURL.path) {
            return legacyURL
        }
        return nil
    }

    private func cacheKey(for photo: Photo, targetSize: CGSize?, scale: CGFloat) -> NSString {
        if let targetSize = targetSize, targetSize.width > 0, targetSize.height > 0 {
            let width = Int(targetSize.width * scale)
            let height = Int(targetSize.height * scale)
            return NSString(string: "\(photo.id.uuidString)_\(width)x\(height)")
        }
        return NSString(string: "\(photo.id.uuidString)_full")
    }

    private func downsampleImage(at url: URL, to size: CGSize, scale: CGFloat) -> UIImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let maxDimension = max(size.width, size.height) * scale
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxDimension))
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }

    @objc private func handleMemoryWarning() {
        imageCache.removeAllObjects()
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
    
    // MARK: - カテゴリサポートメソッド
    
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
        
        // まず日付別にグループ化
        let dateGrouped = Dictionary(grouping: photos) { photo in
            calendar.startOfDay(for: photo.captureDate)
        }
        
        // 各日付内でカテゴリ別にグループ化
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
        // categoryIdなしの既存写真を移行するため
        var needsSave = false
        
        for (_, photo) in photos.enumerated() {
            // 古いフォーマットから読み込まれた写真はcategoryIdが適切に設定されていない
            // Photoのinit(from decoder:)メソッドで処理されるが
            // ファイルを新しい場所に移動する必要がある
            
            guard let photosDirectory = photosDirectory else { continue }
            
            let oldPath = photosDirectory.appendingPathComponent(photo.fileName)
            let categoryDir = photosDirectory.appendingPathComponent(photo.categoryId)
            let newPath = categoryDir.appendingPathComponent(photo.fileName)
            
            if FileManager.default.fileExists(atPath: oldPath.path) &&
               !FileManager.default.fileExists(atPath: newPath.path) {
                do {
                    // 必要に応じてカテゴリディレクトリを作成
                    if !FileManager.default.fileExists(atPath: categoryDir.path) {
                        try FileManager.default.createDirectory(at: categoryDir, withIntermediateDirectories: true)
                    }
                    
                    // ファイルを新しい場所に移動
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
    
    // MARK: - アプリ評価サポート
    
    func getCumulativePhotoDays() -> Int {
        let calendar = Calendar.current
        let uniqueDates = Set(photos.map { calendar.startOfDay(for: $0.captureDate) })
        return uniqueDates.count
    }
    
    func checkAndRequestReviewIfNeeded() {
        Task { @MainActor in
            let userSettings = UserSettingsManager.shared
            
            // ユーザーが既にアプリを評価済みの場合はスキップ
            if userSettings.settings.hasRatedApp {
                return
            }
            
            let cumulativeDays = getCumulativePhotoDays()
            
            // 累積日数が30の倍数か確認（0を除く）
            if cumulativeDays > 0 && cumulativeDays % 30 == 0 {
                // レビューをリクエスト
                if let windowScene = UIApplication.shared.connectedScenes
                    .filter({ $0.activationState == .foregroundActive })
                    .first as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: windowScene)
                    
                    // 再度表示しないように評価済みとマーク
                    userSettings.settings.hasRatedApp = true
                }
            }
        }
    }
    
    // MARK: - 体重データ同期
    
    @MainActor
    func syncWeightData() async {
        await syncWeightDataFromStorage()
    }
    
    @MainActor
    private func syncWeightDataFromStorage() async {
        do {
            let weightEntries = try await WeightStorageService.shared.loadEntries()
            print("[PhotoStorage] Syncing weight data from \(weightEntries.count) weight entries")
            var hasChanges = false
            
            for entry in weightEntries {
                // 同日の全写真を検索（最初の1枚だけでなく）
                let photosForDate = photos.enumerated().compactMap { (index, photo) in
                    Calendar.current.isDate(photo.captureDate, inSameDayAs: entry.date) ? index : nil
                }
                
                if photosForDate.isEmpty {
                    continue
                }
                
                // この日付の全写真を更新
                for photoIndex in photosForDate {
                    var updatedPhoto = photos[photoIndex]
                    var needsUpdate = false
                    
                    // WeightEntryに体重データがある場合は常に同期
                    if entry.weight > 0 && updatedPhoto.weight != entry.weight {
                        updatedPhoto.weight = entry.weight
                        needsUpdate = true
                    }
                    
                    // WeightEntryに体脂肪データがある場合は常に同期
                    if let bodyFat = entry.bodyFatPercentage, updatedPhoto.bodyFatPercentage != bodyFat {
                        updatedPhoto.bodyFatPercentage = bodyFat
                        needsUpdate = true
                    }
                    
                    if needsUpdate {
                        photos[photoIndex] = updatedPhoto
                        hasChanges = true
                        print("[PhotoStorage] Synced weight data to photo id=\(updatedPhoto.id)")
                    }
                }
            }
            
            if hasChanges {
                // 全同期パス後に更新されたメタデータを一度だけ保存
                savePhotosMetadata()
            }
        } catch {
            print("[PhotoStorage] Failed to sync weight data: \(error)")
        }
    }
}

private extension UIImage {
    var cacheCost: Int {
        let pixelWidth = size.width * scale
        let pixelHeight = size.height * scale
        return Int(pixelWidth * pixelHeight * 4)
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
