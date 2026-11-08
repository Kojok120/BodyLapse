import Foundation

enum TimePeriod: String, CaseIterable {
    case week = "7 Days"
    case month = "30 Days"
    case threeMonths = "3 Months"
    case sixMonths = "6 Months"
    case year = "1 Year"
    case twoYears = "2 Years"
    case threeYears = "3 Years"
    case fiveYears = "5 Years"
    
    var localizedString: String {
        switch self {
        case .week: return "calendar.period.7days".localized
        case .month: return "calendar.period.30days".localized
        case .threeMonths: return "calendar.period.3months".localized
        case .sixMonths: return "calendar.period.6months".localized
        case .year: return "calendar.period.1year".localized
        case .twoYears: return "calendar.period.2years".localized
        case .threeYears: return "calendar.period.3years".localized
        case .fiveYears: return "calendar.period.5years".localized
        }
    }
    
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .year: return 365
        case .twoYears: return 730
        case .threeYears: return 1095
        case .fiveYears: return 1825
        }
    }
}

extension TimePeriod {
    /// 日付シートで選べるいちばん古い日。記録のある最初の日まで (表示できる最長の 5 年まで) さかのぼれる。
    /// 記録が今の表示期間の中にしか無いときは、今の表示期間の始まり
    static func earliestSelectableDate(
        earliestRecord: Date?,
        current: TimePeriod,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        let todayStart = calendar.startOfDay(for: today)
        let start = { (period: TimePeriod) in
            calendar.date(byAdding: .day, value: -(period.days - 1), to: todayStart) ?? todayStart
        }
        let currentStart = start(current)
        guard let earliestRecord else { return currentStart }
        let recordStart = max(calendar.startOfDay(for: earliestRecord), start(.fiveYears))
        return min(recordStart, currentStart)
    }

    /// date を表示できるよう、今の期間を必要なだけ広げる。広げなくてよければ今の期間のまま (狭めない)
    static func expanded(_ current: TimePeriod, toInclude date: Date, today: Date = Date(), calendar: Calendar = .current) -> TimePeriod {
        let todayStart = calendar.startOfDay(for: today)
        let target = calendar.startOfDay(for: date)
        let daysBack = (calendar.dateComponents([.day], from: target, to: todayStart).day ?? 0) + 1
        if daysBack <= current.days { return current }
        return allCases
            .filter { $0.days >= current.days }
            .first { $0.days >= daysBack } ?? .fiveYears
    }
}
