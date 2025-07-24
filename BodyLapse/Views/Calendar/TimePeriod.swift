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