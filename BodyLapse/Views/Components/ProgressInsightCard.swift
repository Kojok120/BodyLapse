import SwiftUI

/// 体重の進捗インサイト（変化量・週次ペース・目標進捗）を表示するカード。
/// 全ユーザー無料。体重はkg保存のため、表示時に単位変換する。
struct ProgressInsightCard: View {
    let insight: ProgressInsight
    let unit: UserSettings.WeightUnit
    let onSetGoal: () -> Void

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(spacing: 12) {
            changeRow

            if insight.goalWeight != nil {
                Divider()
                goalSection
            } else {
                Divider()
                Button(action: onSetGoal) {
                    HStack {
                        Image(systemName: "target")
                        Text("goal.set".localized)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.bodyLapseTurquoise)
                }
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(14)
        .padding(.horizontal)
    }

    // MARK: - 変化量サマリー

    private var changeRow: some View {
        HStack(spacing: 0) {
            statColumn(label: "insight.recent".localized, change: insight.recentChange)
            divider
            statColumn(label: "insight.total".localized, change: insight.totalChange)
            divider
            statColumn(label: "insight.weekly".localized, change: insight.weeklyRate)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(UIColor.separator))
            .frame(width: 0.5, height: 28)
    }

    private func statColumn(label: String, change: Double?) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            if let change {
                HStack(spacing: 2) {
                    Image(systemName: change < 0 ? "arrow.down" : (change > 0 ? "arrow.up" : "minus"))
                        .font(.caption2.weight(.bold))
                    Text(formatMagnitude(change))
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.primary)
            } else {
                Text("—")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 目標進捗

    private var goalSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.bodyLapseTurquoise)
                Text("goal.label".localized)
                    .font(.subheadline.weight(.medium))
                Spacer()
                if let goal = insight.goalWeight {
                    Text(formatWeight(goal))
                        .font(.subheadline.weight(.semibold))
                }
                Button(action: onSetGoal) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("goal.edit".localized)
            }

            if let fraction = insight.progressFraction {
                ProgressView(value: fraction)
                    .tint(.bodyLapseTurquoise)
            }

            if insight.hasReachedGoal {
                Text("goal.reached".localized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.bodyLapseTurquoise)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack {
                    if let remaining = insight.remainingToGoal {
                        Text("goal.remaining".localized(with: formatMagnitude(remaining)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if let projected = insight.projectedGoalDate {
                        Text("goal.projected".localized(with: Self.dateFormatter.string(from: projected)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("goal.projected_unknown".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - 表示変換

    private func convert(_ kg: Double) -> Double {
        unit == .kg ? kg : kg * 2.20462
    }

    private func formatWeight(_ kg: Double) -> String {
        String(format: "%.1f %@", convert(kg), unit.symbol)
    }

    /// 符号なしの大きさ（変化量の絶対値）を単位つきで返す。方向は矢印で示す。
    private func formatMagnitude(_ kg: Double) -> String {
        String(format: "%.1f %@", abs(convert(kg)), unit.symbol)
    }
}
