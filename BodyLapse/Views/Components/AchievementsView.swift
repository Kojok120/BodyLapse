import SwiftUI

/// 実績バッジの一覧。解除済み/未解除を一覧表示し、現在の統計サマリーを上部に出す。
struct AchievementsView: View {
    let statistics: PhotoStatistics

    @Environment(\.dismiss) private var dismiss
    @StateObject private var achievementService = AchievementService.shared

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 16)]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    summarySection

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(Achievement.all) { achievement in
                            badgeCell(achievement)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("achievement.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) { dismiss() }
                }
            }
        }
    }

    private var summarySection: some View {
        HStack(spacing: 12) {
            summaryStat(value: statistics.currentStreak, label: "streak.summary.current".localized, icon: "flame.fill", tint: .orange)
            summaryStat(value: statistics.longestStreak, label: "streak.summary.longest".localized, icon: "trophy.fill", tint: .yellow)
            summaryStat(value: statistics.totalDays, label: "streak.summary.total".localized, icon: "calendar", tint: .bodyLapseTurquoise)
        }
        .padding(.horizontal)
    }

    private func summaryStat(value: Int, label: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(tint)
            Text("\(value)")
                .font(.title2.bold())
                .foregroundColor(.primary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func badgeCell(_ achievement: Achievement) -> some View {
        let unlocked = achievementService.isUnlocked(achievement)
        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(unlocked
                          ? AnyShapeStyle(LinearGradient(colors: [Color.orange, Color.bodyLapseTurquoise], startPoint: .topLeading, endPoint: .bottomTrailing))
                          : AnyShapeStyle(Color(UIColor.tertiarySystemFill)))
                    .frame(width: 64, height: 64)
                Image(systemName: unlocked ? achievement.iconName : "lock.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(unlocked ? .white : .secondary)
            }

            Text(achievement.displayName)
                .font(.caption.weight(.medium))
                .foregroundColor(unlocked ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .opacity(unlocked ? 1 : 0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(unlocked
                            ? "\(achievement.displayName), \("achievement.unlocked".localized)"
                            : "\(achievement.displayName), \("achievement.locked".localized)")
    }
}
