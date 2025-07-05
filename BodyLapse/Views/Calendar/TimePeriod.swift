import Foundation

enum TimePeriod: String, CaseIterable {
    case week = "7 Days"
    case month = "30 Days"
    case threeMonths = "3 Months"
    case sixMonths = "6 Months"
    case year = "1 Year"
    
    var localizedString: String {
        switch self {
        case .week: return "calendar.period.7days".localized
        case .month: return "calendar.period.30days".localized
        case .threeMonths: return "calendar.period.3months".localized
        case .sixMonths: return "calendar.period.6months".localized
        case .year: return "calendar.period.1year".localized
        }
    }
    
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .year: return 365
        }
    }
}