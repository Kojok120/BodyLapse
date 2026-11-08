import StoreKit

/// 無料体験の期間を「1週間無料」のような文にする
enum FreeTrialText {
    static func text(value: Int, unit: Product.SubscriptionPeriod.Unit) -> String {
        switch unit {
        case .day:
            // 7 日は「1週間」と書く
            if value % 7 == 0 {
                return "premium.trial_weeks".localized(with: value / 7)
            }
            return "premium.trial_days".localized(with: value)
        case .week:
            return "premium.trial_weeks".localized(with: value)
        case .month:
            return "premium.trial_months".localized(with: value)
        case .year:
            return "premium.trial_years".localized(with: value)
        @unknown default:
            return "premium.trial_generic".localized
        }
    }
}
