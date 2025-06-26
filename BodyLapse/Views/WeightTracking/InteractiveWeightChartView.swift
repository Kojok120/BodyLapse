import SwiftUI
import Charts

@available(iOS 16.0, *)
struct InteractiveWeightChartView: View {
    let entries: [WeightEntry]
    @Binding var selectedDate: Date?
    let currentPhoto: Photo?
    let onEditWeight: () -> Void
    @StateObject private var userSettings = UserSettingsManager()
    
    @State private var plotWidth: CGFloat = 0
    @State private var isDragging = false
    
    private var sortedEntries: [WeightEntry] {
        entries.sorted { $0.date < $1.date }
    }
    
    private var bodyFatEntries: [WeightEntry] {
        sortedEntries.filter { $0.bodyFatPercentage != nil }
    }
    
    private var dateRange: ClosedRange<Date> {
        guard let first = sortedEntries.first?.date,
              let last = sortedEntries.last?.date else {
            let now = Date()
            return now...now
        }
        return first...last
    }
    
    // Calculate Y-axis ranges
    private var weightRange: ClosedRange<Double> {
        let weights = sortedEntries.map { convertedWeight($0.weight) }
        guard let min = weights.min(), let max = weights.max() else {
            return 0...100
        }
        // Ensure we have a valid range even with single data point
        if min == max {
            return (min - 5)...(max + 5)
        }
        let padding = (max - min) * 0.1
        return (min - padding)...(max + padding)
    }
    
    private var bodyFatRange: ClosedRange<Double> {
        let bodyFats = bodyFatEntries.compactMap { $0.bodyFatPercentage }
        guard let min = bodyFats.min(), let max = bodyFats.max() else {
            return 0...50
        }
        // Ensure we have a valid range even with single data point
        if min == max {
            return (min - 5)...(max + 5)
        }
        let padding = (max - min) * 0.1
        return (min - padding)...(max + padding)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Selected data display
            if let selectedEntry = selectedEntry {
                HStack(spacing: 20) {
                    Text(selectedEntry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.headline)
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Weight")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(convertedWeight(selectedEntry.weight), specifier: "%.1f") \(userSettings.settings.weightUnit.symbol)")
                                .font(.body)
                                .foregroundColor(.blue)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(minWidth: 60)
                        
                        if let bodyFat = selectedEntry.bodyFatPercentage {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Body Fat")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(bodyFat, specifier: "%.1f")%")
                                    .font(.body)
                                    .foregroundColor(.orange)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(minWidth: 60)
                        }
                    }
                    
                    Button(action: onEditWeight) {
                        Image(systemName: currentPhoto?.weight != nil ? "pencil.circle.fill" : "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
            }
            
            // Chart
            HStack(spacing: 0) {
                // Left Y-axis labels for weight
                VStack(alignment: .trailing, spacing: 0) {
                    let stepSize = max((weightRange.upperBound - weightRange.lowerBound) / 4, 0.1)
                    ForEach(Array(stride(from: weightRange.upperBound, through: weightRange.lowerBound, by: -stepSize)), id: \.self) { value in
                        Text("\(value, specifier: "%.0f")")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .frame(height: 40)
                        if value > weightRange.lowerBound {
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(width: 30)
                
                // Main chart
                ZStack {
                    // Weight chart
                    Chart {
                        ForEach(sortedEntries) { entry in
                            if sortedEntries.count > 1 {
                                LineMark(
                                    x: .value("Date", entry.date),
                                    y: .value("Weight", convertedWeight(entry.weight))
                                )
                                .foregroundStyle(Color.blue)
                                .interpolationMethod(.catmullRom)
                            }
                            
                            PointMark(
                                x: .value("Date", entry.date),
                                y: .value("Weight", convertedWeight(entry.weight))
                            )
                            .foregroundStyle(Color.blue)
                            .symbolSize(sortedEntries.count == 1 ? 100 : 50)
                        }
                        
                        // Selection indicator
                        if let selectedDate = selectedDate {
                            RuleMark(x: .value("Selected", selectedDate))
                                .foregroundStyle(Color.primary.opacity(0.3))
                                .lineStyle(StrokeStyle(lineWidth: 2))
                                .annotation(position: .top) {
                                    Image(systemName: "arrowtriangle.down.fill")
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .offset(y: -8)
                                }
                        }
                    }
                    .frame(height: 160)
                    .chartXScale(domain: dateRange)
                    .chartYScale(domain: weightRange)
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisGridLine()
                        }
                    }
                    .chartYAxis(.hidden)
                    
                    // Body fat chart overlay
                    if !bodyFatEntries.isEmpty {
                        Chart {
                            ForEach(bodyFatEntries) { entry in
                                if let bodyFat = entry.bodyFatPercentage {
                                    if bodyFatEntries.count > 1 {
                                        LineMark(
                                            x: .value("Date", entry.date),
                                            y: .value("Body Fat", bodyFat)
                                        )
                                        .foregroundStyle(Color.orange)
                                        .interpolationMethod(.catmullRom)
                                    }
                                    
                                    PointMark(
                                        x: .value("Date", entry.date),
                                        y: .value("Body Fat", bodyFat)
                                    )
                                    .foregroundStyle(Color.orange)
                                    .symbolSize(bodyFatEntries.count == 1 ? 100 : 50)
                                }
                            }
                        }
                        .frame(height: 160)
                        .chartXScale(domain: dateRange)
                        .chartYScale(domain: bodyFatRange)
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .allowsHitTesting(false)
                    }
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(15)
                
                // Right Y-axis labels for body fat
                if !bodyFatEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        let stepSize = max((bodyFatRange.upperBound - bodyFatRange.lowerBound) / 4, 0.1)
                        ForEach(Array(stride(from: bodyFatRange.upperBound, through: bodyFatRange.lowerBound, by: -stepSize)), id: \.self) { value in
                            Text("\(value, specifier: "%.0f")%")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .frame(height: 40)
                            if value > bodyFatRange.lowerBound {
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .frame(width: 35)
                }
            }
            .overlay(
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            print("[InteractiveWeightChartView] Tap detected at: \(location)")
                            updateSelection(at: location.x, geometry: geometry, chartProxy: nil)
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    print("[InteractiveWeightChartView] Drag detected at: \(value.location)")
                                    isDragging = true
                                    updateSelection(at: value.location.x, geometry: geometry, chartProxy: nil)
                                }
                                .onEnded { _ in
                                    isDragging = false
                                }
                        )
                }
            )
            
        }
        .onAppear {
            // Select the most recent entry by default
            if selectedDate == nil, let lastEntry = sortedEntries.last {
                selectedDate = lastEntry.date
            }
        }
        .onChange(of: entries) { newEntries in
            // Update selection when entries change
            let sorted = newEntries.sorted { $0.date < $1.date }
            if let lastEntry = sorted.last {
                selectedDate = lastEntry.date
            }
        }
    }
    
    private func updateSelection(at x: CGFloat, geometry: GeometryProxy, chartProxy: ChartProxy?) {
        guard !sortedEntries.isEmpty else { return }
        
        let plotWidth = geometry.size.width
        
        // Calculate the date based on position
        let dateInterval = dateRange.upperBound.timeIntervalSince(dateRange.lowerBound)
        let selectedInterval = (x / plotWidth) * dateInterval
        let selectedTime = dateRange.lowerBound.addingTimeInterval(selectedInterval)
        
        // Find the closest entry
        let closestEntry = sortedEntries.min(by: { entry1, entry2 in
            abs(entry1.date.timeIntervalSince(selectedTime)) < abs(entry2.date.timeIntervalSince(selectedTime))
        })
        
        if let entry = closestEntry {
            selectedDate = entry.date
            print("[InteractiveWeightChartView] Selected date: \(entry.date)")
        }
    }
    
    private var selectedEntry: WeightEntry? {
        guard let selectedDate = selectedDate else { return nil }
        
        // Find the entry for the selected date
        return sortedEntries.first { entry in
            Calendar.current.isDate(entry.date, inSameDayAs: selectedDate)
        }
    }
    
    private func convertedWeight(_ weight: Double) -> Double {
        userSettings.settings.weightUnit == .kg ? weight : weight * 2.20462
    }
}

@available(iOS 16.0, *)
struct InteractiveWeightChartView_Previews: PreviewProvider {
    static var previews: some View {
        InteractiveWeightChartView(
            entries: [],
            selectedDate: .constant(nil),
            currentPhoto: nil,
            onEditWeight: {}
        )
    }
}