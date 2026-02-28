import Foundation
import SwiftUI

class CompareViewModel: ObservableObject {
    @Published var photos: [Photo] = []
    
    init() {
        loadPhotos()
    }
    
    func loadPhotos() {
        Task { @MainActor in
            // ディスクから再読み込み後、1回の同期パスを実行して永続化。
            PhotoStorageService.shared.reloadPhotosFromDisk(syncWeightData: false)
            await PhotoStorageService.shared.syncWeightData()
            photos = PhotoStorageService.shared.photos.sorted { $0.captureDate > $1.captureDate }
            print("[CompareViewModel] Loaded \(photos.count) photos from PhotoStorageService")
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
