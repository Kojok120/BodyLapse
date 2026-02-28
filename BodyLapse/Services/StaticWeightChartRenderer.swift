import Foundation
import UIKit
import CoreGraphics

class StaticWeightChartRenderer {
    static let shared = StaticWeightChartRenderer()
    
    private init() {}
    
    struct ChartOptions {
        let size: CGSize
        let showBodyFat: Bool
        let backgroundColor: UIColor
        let gridColor: UIColor
        let weightLineColor: UIColor
        let bodyFatLineColor: UIColor
        let progressBarColor: UIColor
        let textColor: UIColor
        let font: UIFont
        let isWeightInLbs: Bool
        
        static let `default` = ChartOptions(
            size: CGSize(width: 1080, height: 300),
            showBodyFat: true,
            backgroundColor: .systemBackground,
            gridColor: .systemGray5,
            weightLineColor: UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0),
            bodyFatLineColor: UIColor(red: 1.0, green: 0.624, blue: 0.039, alpha: 1.0),
            progressBarColor: UIColor(red: 0.0, green: 0.8, blue: 0.0, alpha: 0.8),
            textColor: .label,
            font: .systemFont(ofSize: 14),
            isWeightInLbs: false
        )
    }
    
    // 単位設定に基づいて体重を変換するヘルパー
    private func convertedWeight(_ weight: Double, isLbs: Bool) -> Double {
        return isLbs ? weight * 2.20462 : weight
    }
    
    // 値を0-1範囲に正規化するヘルパー（InteractiveWeightChartViewと一致）
    private func normalizeValue(_ value: Double, in range: ClosedRange<Double>) -> Double {
        let rangeSize = range.upperBound - range.lowerBound
        guard rangeSize > 0 else { return 0.5 }
        return (value - range.lowerBound) / rangeSize
    }
    
    // 日付に基づいてX位置を計算（InteractiveWeightChartViewのロジックと一致）
    private func xPosition(for date: Date, in width: CGFloat, dateRange: ClosedRange<Date>) -> CGFloat {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: dateRange.lowerBound)
        let targetDate = calendar.startOfDay(for: date)
        let endDate = calendar.startOfDay(for: dateRange.upperBound)
        
        // 範囲内の総日数を計算
        let totalDays = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        
        // 対象日付のインデックスを計算
        let dayIndex = calendar.dateComponents([.day], from: startDate, to: targetDate).day ?? 0
        
        // 少なくとも1日の範囲を確保
        let safeTotalDays = max(1, totalDays)
        
        // 均等な間隔で位置を計算
        let fraction = CGFloat(dayIndex) / CGFloat(safeTotalDays)
        
        return width * fraction
    }
    
    func renderChart(
        entries: [WeightEntry],
        currentDate: Date,
        dateRange: ClosedRange<Date>,
        options: ChartOptions = .default
    ) -> UIImage? {
        guard !entries.isEmpty else { return nil }
        
        UIGraphicsBeginImageContextWithOptions(options.size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // 背景を描画
        context.setFillColor(options.backgroundColor.cgColor)
        context.fill(CGRect(origin: .zero, size: options.size))
        
        // チャートエリアを計算（パディング付き）
        let padding: CGFloat = 20
        let leftPadding = padding * 3  // Space for weight labels
        let rightPadding = padding * 3  // Increased space for body fat percentage labels
        let chartRect = CGRect(
            x: leftPadding,
            y: padding,
            width: options.size.width - leftPadding - rightPadding,
            height: options.size.height - padding * 3
        )
        
        // 日付範囲内のエントリをフィルター
        let calendar = Calendar.current
        let filteredEntries = entries.filter { entry in
            let entryDate = calendar.startOfDay(for: entry.date)
            let rangeStart = calendar.startOfDay(for: dateRange.lowerBound)
            let rangeEnd = calendar.startOfDay(for: dateRange.upperBound)
            return entryDate >= rangeStart && entryDate <= rangeEnd
        }.sorted { $0.date < $1.date }
        
        guard !filteredEntries.isEmpty else { return nil }
        
        // グリッドを描画
        drawGrid(in: context, rect: chartRect, options: options)
        
        // 適切な正規化でY軸範囲を計算（InteractiveWeightChartViewと一致）
        let weights = filteredEntries.map { convertedWeight($0.weight, isLbs: options.isWeightInLbs) }
        guard let minWeight = weights.min(), let maxWeight = weights.max() else {
            return nil
        }
        
        // パディング付きで体重範囲を計算
        let weightRange: ClosedRange<Double>
        let range = maxWeight - minWeight
        if range < 5 {
            let center = (minWeight + maxWeight) / 2
            weightRange = (center - 5)...(center + 5)
        } else {
            // 10%のパディングを追加
            let padding = range * 0.1
            weightRange = (minWeight - padding)...(maxWeight + padding)
        }
        
        // 体脂肪範囲を計算
        let bodyFatRange: ClosedRange<Double>
        if options.showBodyFat {
            let bodyFats = filteredEntries.compactMap { $0.bodyFatPercentage }
            if let minBodyFat = bodyFats.min(), let maxBodyFat = bodyFats.max() {
                let bfRange = maxBodyFat - minBodyFat
                if bfRange < 5 {
                    let center = (minBodyFat + maxBodyFat) / 2
                    bodyFatRange = (center - 5)...(center + 5)
                } else {
                    // 10%のパディングを追加
                    let padding = bfRange * 0.1
                    bodyFatRange = (minBodyFat - padding)...(maxBodyFat + padding)
                }
            } else {
                bodyFatRange = 15...25 // Default range
            }
        } else {
            bodyFatRange = 15...25 // Default range
        }
        
        // 軸ラベルを描画
        drawAxesLabels(
            in: context,
            rect: chartRect,
            weightRange: weightRange,
            bodyFatRange: bodyFatRange,
            showBodyFat: options.showBodyFat,
            options: options
        )
        
        // データ線を描画
        drawWeightLine(
            entries: filteredEntries,
            in: context,
            rect: chartRect,
            weightRange: weightRange,
            dateRange: dateRange,
            options: options
        )
        
        if options.showBodyFat {
            drawBodyFatLine(
                entries: filteredEntries,
                in: context,
                rect: chartRect,
                bodyFatRange: bodyFatRange,
                dateRange: dateRange,
                options: options
            )
        }
        
        // プログレスバーを描画
        drawProgressBar(
            in: context,
            rect: chartRect,
            currentDate: currentDate,
            dateRange: dateRange,
            options: options
        )
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    private func drawGrid(in context: CGContext, rect: CGRect, options: ChartOptions) {
        context.saveGState()
        
        context.setStrokeColor(options.gridColor.cgColor)
        context.setLineWidth(1)
        
        // 水平線 - InteractiveWeightChartViewと同様に4本
        for i in 0...3 {
            let y = rect.minY + (rect.height / 3.0) * CGFloat(i)
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        
        // 垂直線
        let verticalLines = 6
        for i in 0...verticalLines {
            let x = rect.minX + (rect.width / CGFloat(verticalLines)) * CGFloat(i)
            context.move(to: CGPoint(x: x, y: rect.minY))
            context.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        
        context.strokePath()
        context.restoreGState()
    }
    
    private func drawAxesLabels(
        in context: CGContext,
        rect: CGRect,
        weightRange: ClosedRange<Double>,
        bodyFatRange: ClosedRange<Double>,
        showBodyFat: Bool,
        options: ChartOptions
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: options.font,
            .foregroundColor: options.textColor,
            .paragraphStyle: paragraphStyle
        ]
        
        // 体重ラベル（左軸）- InteractiveWeightChartViewと同様に4つ
        let weightUnit = options.isWeightInLbs ? "lbs" : "kg"
        for i in 0..<4 {
            let fraction = Double(3 - i) / 3.0
            let weight = weightRange.lowerBound + (weightRange.upperBound - weightRange.lowerBound) * fraction
            let y = rect.minY + rect.height * CGFloat(i) / 3.0
            
            let text = String(format: "%.1f%@", weight, weightUnit)
            let textRect = CGRect(x: rect.minX - 55, y: y - options.font.lineHeight / 2, width: 50, height: options.font.lineHeight)
            text.draw(in: textRect, withAttributes: attributes)
        }
        
        // 体脂肪ラベル（右軸）
        if showBodyFat {
            let rightAttributes: [NSAttributedString.Key: Any] = [
                .font: options.font,
                .foregroundColor: options.bodyFatLineColor
            ]
            
            for i in 0..<4 {
                let fraction = Double(3 - i) / 3.0
                let bodyFat = bodyFatRange.lowerBound + (bodyFatRange.upperBound - bodyFatRange.lowerBound) * fraction
                let y = rect.minY + rect.height * CGFloat(i) / 3.0
                
                let text = String(format: "%.1f%%", bodyFat)
                let textRect = CGRect(x: rect.maxX + 5, y: y - options.font.lineHeight / 2, width: 50, height: options.font.lineHeight)
                text.draw(in: textRect, withAttributes: rightAttributes)
            }
        }
    }
    
    private func drawWeightLine(
        entries: [WeightEntry],
        in context: CGContext,
        rect: CGRect,
        weightRange: ClosedRange<Double>,
        dateRange: ClosedRange<Date>,
        options: ChartOptions
    ) {
        guard !entries.isEmpty else { return }
        
        context.saveGState()
        context.setStrokeColor(options.weightLineColor.cgColor)
        context.setLineWidth(3)
        
        let path = UIBezierPath()
        var firstPoint = true
        
        for entry in entries {
            let x = rect.minX + xPosition(for: entry.date, in: rect.width, dateRange: dateRange)
            let convertedWeightValue = convertedWeight(entry.weight, isLbs: options.isWeightInLbs)
            let normalizedValue = normalizeValue(convertedWeightValue, in: weightRange)
            let y = rect.maxY - rect.height * CGFloat(normalizedValue)
            
            if firstPoint {
                path.move(to: CGPoint(x: x, y: y))
                firstPoint = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        context.addPath(path.cgPath)
        context.strokePath()
        
        // ポイントを描画
        context.setFillColor(options.weightLineColor.cgColor)
        for entry in entries {
            let x = rect.minX + xPosition(for: entry.date, in: rect.width, dateRange: dateRange)
            let convertedWeightValue = convertedWeight(entry.weight, isLbs: options.isWeightInLbs)
            let normalizedValue = normalizeValue(convertedWeightValue, in: weightRange)
            let y = rect.maxY - rect.height * CGFloat(normalizedValue)
            
            context.fillEllipse(in: CGRect(x: x - 4, y: y - 4, width: 8, height: 8))
        }
        
        context.restoreGState()
    }
    
    private func drawBodyFatLine(
        entries: [WeightEntry],
        in context: CGContext,
        rect: CGRect,
        bodyFatRange: ClosedRange<Double>,
        dateRange: ClosedRange<Date>,
        options: ChartOptions
    ) {
        let bodyFatEntries = entries.filter { $0.bodyFatPercentage != nil }
        guard !bodyFatEntries.isEmpty else { return }
        
        context.saveGState()
        context.setStrokeColor(options.bodyFatLineColor.cgColor)
        context.setLineWidth(3)
        
        let path = UIBezierPath()
        var firstPoint = true
        
        for entry in bodyFatEntries {
            guard let bodyFat = entry.bodyFatPercentage else { continue }
            
            let x = rect.minX + xPosition(for: entry.date, in: rect.width, dateRange: dateRange)
            let normalizedValue = normalizeValue(bodyFat, in: bodyFatRange)
            let y = rect.maxY - rect.height * CGFloat(normalizedValue)
            
            if firstPoint {
                path.move(to: CGPoint(x: x, y: y))
                firstPoint = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        context.addPath(path.cgPath)
        context.strokePath()
        
        // ポイントを描画
        context.setFillColor(options.bodyFatLineColor.cgColor)
        for entry in bodyFatEntries {
            guard let bodyFat = entry.bodyFatPercentage else { continue }
            
            let x = rect.minX + xPosition(for: entry.date, in: rect.width, dateRange: dateRange)
            let normalizedValue = normalizeValue(bodyFat, in: bodyFatRange)
            let y = rect.maxY - rect.height * CGFloat(normalizedValue)
            
            context.fillEllipse(in: CGRect(x: x - 4, y: y - 4, width: 8, height: 8))
        }
        
        context.restoreGState()
    }
    
    private func drawProgressBar(
        in context: CGContext,
        rect: CGRect,
        currentDate: Date,
        dateRange: ClosedRange<Date>,
        options: ChartOptions
    ) {
        context.saveGState()
        
        // データポイントと同じロジックでプログレス位置を計算
        let x = rect.minX + xPosition(for: currentDate, in: rect.width, dateRange: dateRange)
        
        // 垂直線を描画
        context.setStrokeColor(options.progressBarColor.cgColor)
        context.setLineWidth(3)
        context.move(to: CGPoint(x: x, y: rect.minY))
        context.addLine(to: CGPoint(x: x, y: rect.maxY))
        context.strokePath()
        
        // 上部に円を描画
        context.setFillColor(options.progressBarColor.cgColor)
        context.fillEllipse(in: CGRect(x: x - 6, y: rect.minY - 6, width: 12, height: 12))
        
        context.restoreGState()
    }
}