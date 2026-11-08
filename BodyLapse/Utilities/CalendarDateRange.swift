import Foundation

/// カレンダーの表示期間 (今日で終わる N 日) の日付の並び。
/// body やチャートのドラッグのたびに最長 1825 日分を作り直さないよう、同じ日・同じ日数なら使い回す
enum CalendarDateRange {
    private struct Key: Equatable {
        let end: Date
        let days: Int
    }

    @MainActor private static var cached: (key: Key, dates: [Date])?

    /// end の日 (0:00) で終わる days 日分の 0:00 の並び (古い順)
    @MainActor
    static func dates(days: Int, endingOn end: Date = Date(), calendar: Calendar = .current) -> [Date] {
        let key = Key(end: calendar.startOfDay(for: end), days: days)
        if let cached, cached.key == key {
            return cached.dates
        }
        let dates = makeDates(days: days, endingOn: end, calendar: calendar)
        cached = (key, dates)
        return dates
    }

    static func makeDates(days: Int, endingOn end: Date, calendar: Calendar = .current) -> [Date] {
        guard days > 0 else { return [] }
        let endDay = calendar.startOfDay(for: end)
        return (0..<days).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: endDay)
        }
    }

    /// date が並びの何番目か。先頭からの日数の差で求め、全件を探さない
    static func index(of date: Date, in dates: [Date], calendar: Calendar = .current) -> Int? {
        guard let first = dates.first,
              let offset = calendar.dateComponents([.day], from: first, to: calendar.startOfDay(for: date)).day,
              dates.indices.contains(offset),
              calendar.isDate(dates[offset], inSameDayAs: date) else {
            return nil
        }
        return offset
    }
}
