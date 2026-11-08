import Foundation

/// 月ごとのまとまり。ギャラリーの見出しに使う
struct MonthGroup<Item>: Identifiable {
    /// その月の 1 日 0:00
    let month: Date
    let items: [Item]

    var id: Date { month }
}

enum MonthGrouping {
    /// 月ごとにまとめる。月の並びは newestFirst に従い、月の中の並びは渡した順のまま。
    /// 書式にした文字列でまとめて文字列から日付に戻す作りだと、言語によっては戻せず並びが崩れるので、日付でまとめる
    static func group<Item>(
        _ items: [Item],
        date: (Item) -> Date,
        newestFirst: Bool,
        calendar: Calendar = .current
    ) -> [MonthGroup<Item>] {
        var order: [Date] = []
        var buckets: [Date: [Item]] = [:]
        for item in items {
            let itemDate = date(item)
            let month = calendar.dateInterval(of: .month, for: itemDate)?.start ?? calendar.startOfDay(for: itemDate)
            if buckets[month] == nil {
                order.append(month)
            }
            buckets[month, default: []].append(item)
        }
        let months = order.sorted { newestFirst ? $0 > $1 : $0 < $1 }
        return months.map { MonthGroup(month: $0, items: buckets[$0] ?? []) }
    }
}
