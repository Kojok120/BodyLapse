import Foundation

/// 動画にする期間と枚数を決める純関数
enum VideoRangePlanner {
    /// 既定の期間: 選んだカテゴリの最初の写真の日から今日まで (写真が無ければ今日だけ)
    static func defaultRange(photos: [Photo], categoryIds: Set<String>, today: Date, calendar: Calendar = .current) -> ClosedRange<Date> {
        let end = calendar.startOfDay(for: today)
        let earliest = photos
            .filter { categoryIds.isEmpty || categoryIds.contains($0.categoryId) }
            .map(\.captureDate)
            .min()
        let start = earliest.map { min(calendar.startOfDay(for: $0), end) } ?? end
        return start...end
    }

    /// 期間 (日単位、両端を含む) に入る、選んだカテゴリの写真の枚数。
    /// 終了日の 0:00 で比べると、その日に撮った写真が数に入らなかった
    static func photoCount(photos: [Photo], from start: Date, to end: Date, categoryIds: Set<String>, calendar: Calendar = .current) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        return photos.filter { photo in
            let day = calendar.startOfDay(for: photo.captureDate)
            return day >= startDay && day <= endDay && (categoryIds.isEmpty || categoryIds.contains(photo.categoryId))
        }.count
    }
}
