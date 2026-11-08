import Foundation
import SwiftUI

/// 比較の初期の組み合わせと差分を決める純関数
enum ComparePairing {
    /// そのカテゴリで最も古い写真を「変化前」、最も新しい写真を「変化後」にする。1 枚しか無ければ変化後だけ。
    static func defaultPair(from photos: [Photo], categoryId: String) -> (before: Photo?, after: Photo?) {
        let inCategory = photos
            .filter { $0.categoryId == categoryId }
            .sorted { $0.captureDate < $1.captureDate }
        guard let latest = inCategory.last else { return (nil, nil) }
        guard let earliest = inCategory.first, earliest.id != latest.id else { return (nil, latest) }
        return (earliest, latest)
    }

    /// 指定日・カテゴリの写真
    static func photo(on date: Date, categoryId: String, in photos: [Photo], calendar: Calendar = .current) -> Photo? {
        photos.first { $0.categoryId == categoryId && calendar.isDate($0.captureDate, inSameDayAs: date) }
    }

    /// 後 − 前。どちらかが無ければ nil。
    static func difference(before: Double?, after: Double?) -> Double? {
        guard let before, let after else { return nil }
        return after - before
    }
}

@MainActor
final class CompareViewModel: ObservableObject {
    @Published private(set) var photos: [Photo] = []
    /// 日 (startOfDay) ごとの体重・体脂肪率の記録。体重の正はこちらで、写真に写した値は予備。
    @Published private(set) var entriesByDay: [Date: WeightEntry] = [:]

    init() {
        refresh()
    }

    /// メモリ上の写真一覧と体重の記録を読み直す。ディスクの読み直しや画像キャッシュの破棄はしない。
    func refresh() {
        photos = PhotoStorageService.shared.photos.sorted { $0.captureDate > $1.captureDate }
        Task {
            let entries = (try? await WeightStorageService.shared.loadEntries()) ?? []
            let calendar = Calendar.current
            var byDay: [Date: WeightEntry] = [:]
            for entry in entries {
                byDay[calendar.startOfDay(for: entry.date)] = entry
            }
            entriesByDay = byDay
        }
    }

    func photo(on date: Date, categoryId: String) -> Photo? {
        ComparePairing.photo(on: date, categoryId: categoryId, in: photos)
    }

    /// 写真の日の体重 (kg)。体重 0 は「体重なし」。
    func weight(for photo: Photo) -> Double? {
        if let entry = entriesByDay[Calendar.current.startOfDay(for: photo.captureDate)] {
            return entry.weight > 0 ? entry.weight : nil
        }
        return photo.weight
    }

    func bodyFat(for photo: Photo) -> Double? {
        if let entry = entriesByDay[Calendar.current.startOfDay(for: photo.captureDate)] {
            return entry.bodyFatPercentage
        }
        return photo.bodyFatPercentage
    }
}
