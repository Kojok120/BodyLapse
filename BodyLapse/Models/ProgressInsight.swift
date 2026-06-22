import Foundation

/// 体重の進捗インサイト（変化量・週次ペース・目標到達予測など）。
/// 体重エントリ（kg）と任意の目標体重から純粋関数で算出し、UIから独立してテスト可能にする。
struct ProgressInsight: Equatable {
    let currentWeight: Double?      // kg（最新）
    let startWeight: Double?        // kg（最古）
    let totalChange: Double?        // current - start（kg、符号つき）
    let recentChange: Double?       // 直近ウィンドウ（既定30日）の変化（kg、符号つき）
    let weeklyRate: Double?         // 週あたりの変化ペース（kg/週、符号つき・回帰）

    // 目標関連（goalWeight 指定時のみ）
    let goalWeight: Double?
    let remainingToGoal: Double?    // |current - goal|（kg）
    let progressFraction: Double?   // 0...1（start→goal の達成率）
    let projectedGoalDate: Date?    // 直近ペースから推定する達成予定日
    let hasReachedGoal: Bool

    static let empty = ProgressInsight(
        currentWeight: nil, startWeight: nil, totalChange: nil, recentChange: nil,
        weeklyRate: nil, goalWeight: nil, remainingToGoal: nil, progressFraction: nil,
        projectedGoalDate: nil, hasReachedGoal: false
    )

    var hasData: Bool { currentWeight != nil }

    /// - Note: 「直近」「週次ペース」はすべて最新エントリの日付を基準に算出する。
    static func compute(entries: [WeightEntry],
                        goalWeight: Double? = nil,
                        recentWindowDays: Int = 30,
                        regressionWindowDays: Int = 56,
                        calendar: Calendar = .current) -> ProgressInsight {
        let sorted = entries.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last else { return .empty }

        let current = last.weight
        let start = first.weight
        let totalChange = current - start

        // 直近ウィンドウの変化：currentDate から recentWindowDays 前以前で最新のエントリを基準にする
        let currentDate = last.date
        let recentBoundary = calendar.date(byAdding: .day, value: -recentWindowDays, to: currentDate) ?? currentDate
        let baselineForRecent = sorted.last(where: { $0.date <= recentBoundary }) ?? first
        let recentChange = current - baselineForRecent.weight

        // 週次ペース：直近 regressionWindowDays のエントリで線形回帰（点が足りなければ全件）
        let regressionBoundary = calendar.date(byAdding: .day, value: -regressionWindowDays, to: currentDate) ?? currentDate
        var regressionPoints = sorted.filter { $0.date >= regressionBoundary }
        if regressionPoints.count < 2 { regressionPoints = sorted }
        let weeklyRate = Self.computeWeeklyRate(from: regressionPoints, calendar: calendar)

        guard let goal = goalWeight else {
            return ProgressInsight(
                currentWeight: current, startWeight: start, totalChange: totalChange,
                recentChange: recentChange, weeklyRate: weeklyRate, goalWeight: nil,
                remainingToGoal: nil, progressFraction: nil, projectedGoalDate: nil,
                hasReachedGoal: false
            )
        }

        let remaining = abs(current - goal)

        // 達成判定（開始→目標の向きに対して、現在が目標を越えたか）
        let losing = goal <= start
        let hasReached = losing ? current <= goal : current >= goal

        // 達成率：start→goal を 0...1 に。start == goal の場合は達成なら1、そうでなければnil。
        let progressFraction: Double?
        if start == goal {
            progressFraction = hasReached ? 1 : nil
        } else {
            let raw = (start - current) / (start - goal)
            progressFraction = min(max(raw, 0), 1)
        }

        // 達成予定日：未達かつペースが目標方向で十分な大きさのときのみ推定
        var projectedGoalDate: Date? = nil
        if !hasReached, let rate = weeklyRate {
            let ratePerDay = rate / 7.0
            let needLoss = goal < current
            let movingTowardGoal = needLoss ? ratePerDay < 0 : ratePerDay > 0
            if movingTowardGoal, abs(rate) >= 0.05 {
                let daysNeeded = (goal - current) / ratePerDay // 正の値になる
                if daysNeeded.isFinite, daysNeeded >= 0, daysNeeded <= 365 * 5 {
                    projectedGoalDate = calendar.date(byAdding: .day, value: Int(daysNeeded.rounded()), to: currentDate)
                }
            }
        }

        return ProgressInsight(
            currentWeight: current, startWeight: start, totalChange: totalChange,
            recentChange: recentChange, weeklyRate: weeklyRate, goalWeight: goal,
            remainingToGoal: remaining, progressFraction: progressFraction,
            projectedGoalDate: hasReached ? currentDate : projectedGoalDate,
            hasReachedGoal: hasReached
        )
    }

    /// 線形回帰の傾き（kg/日）を週次（kg/週）に換算して返す。点が2未満ならnil。
    private static func computeWeeklyRate(from points: [WeightEntry], calendar: Calendar) -> Double? {
        guard points.count >= 2, let firstDate = points.first?.date else { return nil }
        // x = 経過日数、y = 体重
        var xs: [Double] = []
        var ys: [Double] = []
        for p in points {
            let days = calendar.dateComponents([.day], from: firstDate, to: p.date).day ?? 0
            xs.append(Double(days))
            ys.append(p.weight)
        }
        let n = Double(xs.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n
        var numerator = 0.0
        var denominator = 0.0
        for i in 0..<xs.count {
            numerator += (xs[i] - meanX) * (ys[i] - meanY)
            denominator += (xs[i] - meanX) * (xs[i] - meanX)
        }
        guard denominator != 0 else { return nil }
        let slopePerDay = numerator / denominator
        return slopePerDay * 7.0
    }
}
