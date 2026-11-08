import UIKit

/// 動画に重ねる体重のグラフ。
///
/// コマごとに変わるのはプログレスバーとその日の数字だけなので、グラフの本体 (絞り込み・並べ替え・線) は
/// 生成ごとに一度だけ描く。画面の倍率ではなく、動画の画素と同じ大きさ (scale 1) で描く。
final class VideoWeightChartOverlay {
    let isWeightInLbs: Bool

    private let entries: [WeightEntry]
    private let dateRange: ClosedRange<Date>
    private let entriesByDay: [Date: WeightEntry]
    private var cachedBase: (size: CGSize, base: StaticWeightChartRenderer.BaseChart)?
    private let calendar = Calendar.current

    init(entries: [WeightEntry], dateRange: ClosedRange<Date>, isWeightInLbs: Bool) {
        self.entries = entries
        self.dateRange = dateRange
        self.isWeightInLbs = isWeightInLbs
        // 同じ日に複数あるときは、これまでどおり先に見つかった方を使う
        var byDay: [Date: WeightEntry] = [:]
        for entry in entries {
            let day = Calendar.current.startOfDay(for: entry.date)
            if byDay[day] == nil {
                byDay[day] = entry
            }
        }
        self.entriesByDay = byDay
    }

    /// その日の記録
    func entry(on date: Date) -> WeightEntry? {
        entriesByDay[calendar.startOfDay(for: date)]
    }

    /// currentDate の位置にプログレスバーを重ねたグラフ
    func image(for currentDate: Date, chartSize: CGSize) -> UIImage? {
        guard let base = base(for: chartSize) else { return nil }
        return StaticWeightChartRenderer.shared.compose(base, currentDate: currentDate)
    }

    private func base(for chartSize: CGSize) -> StaticWeightChartRenderer.BaseChart? {
        if let cachedBase, cachedBase.size == chartSize {
            return cachedBase.base
        }
        guard let base = StaticWeightChartRenderer.shared.renderBase(
            entries: entries,
            dateRange: dateRange,
            options: Self.chartOptions(size: chartSize, isWeightInLbs: isWeightInLbs),
            scale: 1
        ) else {
            return nil
        }
        cachedBase = (chartSize, base)
        return base
    }

    static func chartOptions(size: CGSize, isWeightInLbs: Bool) -> StaticWeightChartRenderer.ChartOptions {
        StaticWeightChartRenderer.ChartOptions(
            size: size,
            showBodyFat: true,
            backgroundColor: UIColor.black.withAlphaComponent(0.8),
            gridColor: UIColor.white.withAlphaComponent(0.2),
            weightLineColor: UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0),
            bodyFatLineColor: UIColor(red: 1.0, green: 0.624, blue: 0.039, alpha: 1.0),
            progressBarColor: UIColor(red: 0.0, green: 0.8, blue: 0.0, alpha: 0.8),
            textColor: .white,
            font: .systemFont(ofSize: 12),
            isWeightInLbs: isWeightInLbs
        )
    }
}
