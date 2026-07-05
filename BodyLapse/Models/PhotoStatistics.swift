import Foundation

/// 撮影習慣の統計（ストリーク・月内日数など）。
/// 撮影日の集合から純粋関数で計算するため、テスト容易かつUIから独立。
struct PhotoStatistics: Equatable {
    /// 今日（または今日未撮影なら昨日）まで連続して撮影した日数。途切れていれば0。
    let currentStreak: Int
    /// 過去最長の連続撮影日数。
    let longestStreak: Int
    /// 今月撮影した日数。
    let daysThisMonth: Int
    /// 撮影した延べ日数（ユニーク）。
    let totalDays: Int
    /// 今日すでに撮影済みか。
    let isTodayCaptured: Bool

    static let empty = PhotoStatistics(
        currentStreak: 0,
        longestStreak: 0,
        daysThisMonth: 0,
        totalDays: 0,
        isTodayCaptured: false
    )

    /// 撮影日（任意の時刻でよい）の集合から統計を計算する。
    /// - Parameters:
    ///   - photographedDays: 1枚以上の写真がある日付の集合。
    ///   - referenceDate: 「今日」とみなす基準日（テスト用に注入可能）。
    ///   - calendar: 使用するカレンダー。
    static func compute(from photographedDays: Set<Date>,
                        referenceDate: Date = Date(),
                        calendar: Calendar = .current) -> PhotoStatistics {
        guard !photographedDays.isEmpty else { return .empty }

        // すべて startOfDay に正規化して重複を排除。
        let days = Set(photographedDays.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: referenceDate)
        let isTodayCaptured = days.contains(today)

        // 現在のストリーク: 今日があれば今日から、なければ昨日から遡る。
        // （今日まだ未撮影でも、昨日まで続いていればストリークは「生存中」とみなす）
        var anchor: Date?
        if days.contains(today) {
            anchor = today
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  days.contains(yesterday) {
            anchor = yesterday
        }

        var currentStreak = 0
        if var cursor = anchor {
            while days.contains(cursor) {
                currentStreak += 1
                guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = previous
            }
        }

        // 最長ストリーク: 昇順に並べて連続ランの最大長を求める。
        let sorted = days.sorted()
        var longestStreak = 0
        var run = 0
        var previousDay: Date?
        for day in sorted {
            if let previous = previousDay,
               let expectedNext = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(expectedNext, inSameDayAs: day) {
                run += 1
            } else {
                run = 1
            }
            longestStreak = max(longestStreak, run)
            previousDay = day
        }

        // 今月の撮影日数。
        let monthComponents = calendar.dateComponents([.year, .month], from: today)
        let daysThisMonth = days.filter { day in
            let components = calendar.dateComponents([.year, .month], from: day)
            return components.year == monthComponents.year && components.month == monthComponents.month
        }.count

        return PhotoStatistics(
            currentStreak: currentStreak,
            longestStreak: max(longestStreak, currentStreak),
            daysThisMonth: daysThisMonth,
            totalDays: days.count,
            isTodayCaptured: isTodayCaptured
        )
    }
}
