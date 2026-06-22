import SwiftUI

/// カレンダー上部に表示する撮影ストリーク（連続記録）バッジ。
/// 毎日撮る動機づけのため、連続日数・今月の撮影日数・最長記録を可視化する。
struct StreakBadgeView: View {
    let statistics: PhotoStatistics

    var body: some View {
        HStack(spacing: 12) {
            if statistics.currentStreak > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        // 今日まだ未撮影ならフレームを少し淡くして「続けよう」を示唆
                        .foregroundColor(statistics.isTodayCaptured ? .orange : .orange.opacity(0.55))
                    Text("streak.current".localized(with: statistics.currentStreak))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                }

                Spacer(minLength: 8)

                HStack(spacing: 10) {
                    statPill(icon: "calendar", text: "streak.days_this_month".localized(with: statistics.daysThisMonth))
                    statPill(icon: "trophy.fill", text: "streak.longest".localized(with: statistics.longestStreak))
                }
            } else {
                Image(systemName: "camera.badge.clock")
                    .foregroundColor(.bodyLapseTurquoise)
                Text("streak.start".localized)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func statPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption)
        }
        .foregroundColor(.secondary)
        .lineLimit(1)
    }

    private var accessibilityText: String {
        guard statistics.currentStreak > 0 else {
            return "streak.start".localized
        }
        return [
            "streak.current".localized(with: statistics.currentStreak),
            "streak.days_this_month".localized(with: statistics.daysThisMonth),
            "streak.longest".localized(with: statistics.longestStreak)
        ].joined(separator: ", ")
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        StreakBadgeView(statistics: PhotoStatistics(currentStreak: 7, longestStreak: 14, daysThisMonth: 12, totalDays: 40, isTodayCaptured: true))
        StreakBadgeView(statistics: PhotoStatistics(currentStreak: 3, longestStreak: 14, daysThisMonth: 5, totalDays: 40, isTodayCaptured: false))
        StreakBadgeView(statistics: .empty)
    }
    .padding(.vertical)
}
#endif
