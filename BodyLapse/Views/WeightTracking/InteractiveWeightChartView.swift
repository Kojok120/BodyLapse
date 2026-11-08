import SwiftUI
import Charts

/// チャートに描く点と縦軸の範囲。body の評価ごとに一度だけ作る
/// (点ごとに並べ替えや範囲の計算をやり直すと、記録が増えるほど描画が遅くなる)。
struct WeightChartData {
    struct Point: Identifiable {
        let id: UUID
        let date: Date
        let value: Double
    }

    let weightPoints: [Point]
    let bodyFatPoints: [Point]
    let weightRange: ClosedRange<Double>
    let bodyFatRange: ClosedRange<Double>

    static let defaultWeightRange: ClosedRange<Double> = 70...80
    static let defaultBodyFatRange: ClosedRange<Double> = 15...25

    init(entries: [WeightEntry], unit: UserSettings.WeightUnit) {
        let sorted = entries.sorted { $0.date < $1.date }
        // 体重 0 は「体重なし」(過去に体脂肪率だけ保存したときの値)。体重の線には載せない
        weightPoints = sorted
            .filter { $0.weight > 0 }
            .map { Point(id: $0.id, date: $0.date, value: MeasurementInput.displayWeight(kg: $0.weight, unit: unit)) }
        bodyFatPoints = sorted.compactMap { entry in
            entry.bodyFatPercentage.map { Point(id: entry.id, date: entry.date, value: $0) }
        }
        weightRange = Self.paddedRange(for: weightPoints.map(\.value), default: Self.defaultWeightRange)
        bodyFatRange = Self.paddedRange(for: bodyFatPoints.map(\.value), default: Self.defaultBodyFatRange)
    }

    /// 値の最小〜最大に 10% の余白を足した範囲。幅が 5 未満なら中心から ±5 にする。
    static func paddedRange(for values: [Double], default defaultRange: ClosedRange<Double>) -> ClosedRange<Double> {
        guard let minValue = values.min(), let maxValue = values.max() else {
            return defaultRange
        }
        let span = maxValue - minValue
        if span < 5 {
            let center = (minValue + maxValue) / 2
            return (center - 5)...(center + 5)
        }
        let padding = span * 0.1
        return (minValue - padding)...(maxValue + padding)
    }

    /// 範囲の中での位置 (0 = 下端、1 = 上端)
    static func normalized(_ value: Double, in range: ClosedRange<Double>) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0.5 }
        return (value - range.lowerBound) / span
    }
}

struct InteractiveWeightChartView: View {
    let entries: [WeightEntry]
    @Binding var selectedDate: Date?
    let fullDateRange: ClosedRange<Date>? // 全体の期間を指定
    @StateObject private var userSettings = UserSettingsManager.shared
    
    @State private var isDragging = false
    
    // 制約付き日付範囲 - 今日を超えない
    private func constrainedDateRange(_ data: WeightChartData) -> ClosedRange<Date> {
        let today = Date()
        
        if let fullRange = fullDateRange {
            // fullDateRangeを使用するが今日が上限
            let upperBound = max(fullRange.lowerBound, min(fullRange.upperBound, today))
            return fullRange.lowerBound...upperBound
        }
        
        // エントリーベースの範囲にフォールバック
        let dates = (data.weightPoints + data.bodyFatPoints).map(\.date)
        guard let first = dates.min(), let last = dates.max() else {
            return today...today
        }
        
        let upperBound = max(first, min(last, today))
        return first...upperBound
    }
    
    var body: some View {
        let data = WeightChartData(entries: entries, unit: userSettings.settings.weightUnit)
        let weightRange = data.weightRange
        let bodyFatRange = data.bodyFatRange
        let dateRange = constrainedDateRange(data)
        return VStack(alignment: .leading, spacing: 8) {
            // 正規化Y軸付きチャート
            HStack(spacing: 0) {
                // 体重用の左Y軸ラベル
                VStack(alignment: .trailing, spacing: 0) {
                    // 4つの等間隔ラベルを作成
                    ForEach(0..<4) { index in
                        let fraction = Double(3 - index) / 3.0
                        let value = weightRange.lowerBound + (weightRange.upperBound - weightRange.lowerBound) * fraction
                        
                        Text("\(Int(round(value)))\(userSettings.settings.weightUnit.symbol)")
                            .font(.caption2)
                            .foregroundColor(.bodyLapseTurquoise)
                            .frame(maxHeight: .infinity, alignment: index == 0 ? .top : (index == 3 ? .bottom : .center))
                    }
                }
                .frame(width: 40, height: 160)
                .padding(.trailing, 4)
                
                // メインチャートエリア
                ZStack {
                    // 背景
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                    
                    // チャートコンテンツ
                    GeometryReader { geometry in
                        let chartWidth = geometry.size.width
                        let chartHeight = geometry.size.height
                        let padding: CGFloat = 20 // Horizontal padding for dots
                        let dotRadius: CGFloat = 3 // Half of dot size (6/2)
                        
                        ZStack {
                        // Grid lines
                        Path { path in
                            // Horizontal grid lines
                            for i in 0...3 {
                                let y = chartHeight * CGFloat(i) / 3
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: chartWidth, y: y))
                            }
                        }
                        .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                        
                        // Weight data
                        if !data.weightPoints.isEmpty {
                            // Line
                            if data.weightPoints.count > 1 {
                                Path { path in
                                    for (index, point) in data.weightPoints.enumerated() {
                                        let x = padding + xPosition(for: point.date, in: chartWidth - 2 * padding, dateRange: dateRange)
                                        let normalizedY = 1 - WeightChartData.normalized(point.value, in: weightRange)
                                        let y = chartHeight * normalizedY
                                        
                                        if index == 0 {
                                            path.move(to: CGPoint(x: x, y: y))
                                        } else {
                                            path.addLine(to: CGPoint(x: x, y: y))
                                        }
                                    }
                                }
                                .stroke(Color.bodyLapseTurquoise, lineWidth: 2)
                            }
                            
                            // Points
                            let weightDotSize: CGFloat = data.weightPoints.count == 1 ? 10 : 6
                            ForEach(data.weightPoints) { point in
                                let x = padding + xPosition(for: point.date, in: chartWidth - 2 * padding, dateRange: dateRange)
                                let normalizedY = 1 - WeightChartData.normalized(point.value, in: weightRange)
                                let y = chartHeight * normalizedY
                                
                                Circle()
                                    .fill(Color.bodyLapseTurquoise)
                                    .frame(width: weightDotSize, height: weightDotSize)
                                    .position(x: x, y: y)
                            }
                        }
                        
                        // Body fat data
                        if !data.bodyFatPoints.isEmpty {
                            // Line
                            if data.bodyFatPoints.count > 1 {
                                Path { path in
                                    for (index, point) in data.bodyFatPoints.enumerated() {
                                        let x = padding + xPosition(for: point.date, in: chartWidth - 2 * padding, dateRange: dateRange)
                                        let normalizedY = 1 - WeightChartData.normalized(point.value, in: bodyFatRange)
                                        let y = chartHeight * normalizedY
                                        
                                        if index == 0 {
                                            path.move(to: CGPoint(x: x, y: y))
                                        } else {
                                            path.addLine(to: CGPoint(x: x, y: y))
                                        }
                                    }
                                }
                                .stroke(Color.orange, lineWidth: 2)
                            }
                            
                            // Points
                            let bodyFatDotSize: CGFloat = data.bodyFatPoints.count == 1 ? 10 : 6
                            ForEach(data.bodyFatPoints) { point in
                                let x = padding + xPosition(for: point.date, in: chartWidth - 2 * padding, dateRange: dateRange)
                                let normalizedY = 1 - WeightChartData.normalized(point.value, in: bodyFatRange)
                                let y = chartHeight * normalizedY
                                
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: bodyFatDotSize, height: bodyFatDotSize)
                                    .position(x: x, y: y)
                            }
                        }
                        
                        // Selection indicator
                        if let selectedDate = selectedDate {
                            let x = padding + xPosition(for: selectedDate, in: chartWidth - 2 * padding, dateRange: dateRange)
                            
                            Rectangle()
                                .fill(Color.primary.opacity(0.2))
                                .frame(width: 2)
                                .position(x: x, y: chartHeight / 2)
                                .frame(height: chartHeight)
                            
                            // Triangle indicator at top
                            Path { path in
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x - 6, y: -10))
                                path.addLine(to: CGPoint(x: x + 6, y: -10))
                                path.closeSubpath()
                            }
                            .fill(Color.primary)
                            .offset(y: -5)
                        }
                        
                        // Interaction overlay
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                let adjustedX = location.x - padding
                                updateSelection(at: adjustedX, width: chartWidth - 2 * padding, data: data, dateRange: dateRange)
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        isDragging = true
                                        let adjustedX = value.location.x - padding
                                        updateSelection(at: adjustedX, width: chartWidth - 2 * padding, data: data, dateRange: dateRange)
                                    }
                                    .onEnded { _ in
                                        isDragging = false
                                    }
                            )
                        }
                    }
                    .frame(height: 160)
                    .clipped()
                }
                
                // Right Y-axis labels for body fat
                if !data.bodyFatPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        // 4つの等間隔ラベルを作成
                        ForEach(0..<4) { index in
                            let fraction = Double(3 - index) / 3.0
                            let value = bodyFatRange.lowerBound + (bodyFatRange.upperBound - bodyFatRange.lowerBound) * fraction
                            
                            Text(String(format: "weight.percentage_format".localized, value))
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .frame(maxHeight: .infinity, alignment: index == 0 ? .top : (index == 3 ? .bottom : .center))
                        }
                    }
                    .frame(width: 35, height: 160)
                    .padding(.leading, 4)
                }
            }
        }
        .onAppear {
            // 未選択のときだけ最新の記録を選ぶ (選んでいる日は保存や期間の切り替えで動かさない)
            if selectedDate == nil, let latest = (data.weightPoints + data.bodyFatPoints).map(\.date).max() {
                selectedDate = latest
            }
        }
    }
    
    private func xPosition(for date: Date, in width: CGFloat, dateRange: ClosedRange<Date>) -> CGFloat {
        // If we have a fullDateRange, use index-based positioning for even spacing
        if let fullRange = fullDateRange {
            let calendar = Calendar.current
            let startDate = calendar.startOfDay(for: fullRange.lowerBound)
            let targetDate = calendar.startOfDay(for: date)
            let endDate = calendar.startOfDay(for: min(fullRange.upperBound, Date()))
            
            // Calculate total days in range
            let totalDays = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
            
            // Calculate index of target date
            let dayIndex = calendar.dateComponents([.day], from: startDate, to: targetDate).day ?? 0
            
            // Ensure we have at least 1 day range
            let safeTotalDays = max(1, totalDays)
            
            // Calculate position with even spacing
            let fraction = CGFloat(dayIndex) / CGFloat(safeTotalDays)
            
            return width * fraction
        }
        
        // Fallback to time-based positioning
        let range = dateRange
        let totalInterval = range.upperBound.timeIntervalSince(range.lowerBound)
        
        if totalInterval <= 0 {
            return width / 2
        }
        
        let dateInterval = date.timeIntervalSince(range.lowerBound)
        let fraction = dateInterval / totalInterval
        let clampedFraction = max(0, min(1, fraction))
        
        return width * CGFloat(clampedFraction)
    }
    
    private func updateSelection(at x: CGFloat, width: CGFloat, data: WeightChartData, dateRange: ClosedRange<Date>) {
        // Calculate fraction directly
        let fraction = x / width
        let clampedFraction = max(0, min(1, fraction))
        
        // If we have a fullDateRange, use index-based selection for consistency
        if let fullRange = fullDateRange {
            let calendar = Calendar.current
            let startDate = calendar.startOfDay(for: fullRange.lowerBound)
            let endDate = calendar.startOfDay(for: min(fullRange.upperBound, Date()))
            
            // Calculate total days in range
            let totalDays = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
            let safeTotalDays = max(1, totalDays)
            
            // Calculate which day index was selected
            let selectedDayIndex = Int(round(CGFloat(safeTotalDays) * clampedFraction))
            let clampedIndex = min(selectedDayIndex, safeTotalDays)
            
            // Calculate the selected date
            if let selectedDate = calendar.date(byAdding: .day, value: clampedIndex, to: startDate) {
                self.selectedDate = min(selectedDate, Date())
            }
            return
        }
        
        // Fallback to time-based selection
        let range = dateRange
        let totalInterval = range.upperBound.timeIntervalSince(range.lowerBound)
        let selectedInterval = totalInterval * Double(clampedFraction)
        let selectedTime = range.lowerBound.addingTimeInterval(selectedInterval)
        
        // Ensure we don't select future dates
        let today = Date()
        let constrainedTime = min(selectedTime, today)
        
        // Snap to nearest data point
        if let closestPoint = (data.weightPoints + data.bodyFatPoints).min(by: { point1, point2 in
            abs(point1.date.timeIntervalSince(constrainedTime)) < abs(point2.date.timeIntervalSince(constrainedTime))
        }) {
            selectedDate = closestPoint.date
        } else {
            selectedDate = constrainedTime
        }
    }
}

struct InteractiveWeightChartView_Previews: PreviewProvider {
    static var previews: some View {
        InteractiveWeightChartView(
            entries: [],
            selectedDate: .constant(nil),
            fullDateRange: nil
        )
    }
}