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
        let padding = (max - min) * 0.1
        return (min - padding)...(max + padding)
    }
    
    private var bodyFatRange: ClosedRange<Double> {
        let bodyFats = bodyFatEntries.compactMap { $0.bodyFatPercentage }
        guard let min = bodyFats.min(), let max = bodyFats.max() else {
            return 0...50
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
                    
                    HStack(spacing: 15) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Weight")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(convertedWeight(selectedEntry.weight), specifier: "%.1f") \(userSettings.settings.weightUnit.symbol)")
                                .font(.body)
                                .foregroundColor(.blue)
                        }
                        
                        if let bodyFat = selectedEntry.bodyFatPercentage {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Body Fat")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(bodyFat, specifier: "%.1f")%")
                                    .font(.body)
                                    .foregroundColor(.orange)
                            }
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
            Chart {
                // Weight data - Primary Y axis (left)
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
            .frame(height: 200)
            .chartXScale(domain: dateRange)
            .chartYScale(domain: weightRange)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text("\(doubleValue, specifier: "%.0f") \(userSettings.settings.weightUnit.symbol)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                // Body fat data - Secondary Y axis (right)
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
                    .frame(height: 200)
                    .chartXScale(domain: dateRange)
                    .chartYScale(domain: bodyFatRange)
                    .chartXAxis {
                        AxisMarks { _ in }
                    }
                    .chartYAxis {
                        AxisMarks(position: .trailing) { value in
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text("\(doubleValue, specifier: "%.0f")%")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(15)
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
            
            // Legend
            HStack(spacing: 30) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 10, height: 10)
                    Text("Weight (\(userSettings.settings.weightUnit.symbol))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !bodyFatEntries.isEmpty {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 10, height: 10)
                        Text("Body Fat (%)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
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