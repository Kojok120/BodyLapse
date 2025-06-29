import SwiftUI
import Charts

@available(iOS 16.0, *)
struct InteractiveWeightChartView: View {
    let entries: [WeightEntry]
    @Binding var selectedDate: Date?
    let currentPhoto: Photo?
    let onEditWeight: () -> Void
    let fullDateRange: ClosedRange<Date>? // 全体の期間を指定
    @StateObject private var userSettings = UserSettingsManager.shared
    
    @State private var plotWidth: CGFloat = 0
    @State private var isDragging = false
    
    private var sortedEntries: [WeightEntry] {
        entries.sorted { $0.date < $1.date }
    }
    
    private var bodyFatEntries: [WeightEntry] {
        sortedEntries.filter { $0.bodyFatPercentage != nil }
    }
    
    // Constrained date range - never go beyond today
    private var constrainedDateRange: ClosedRange<Date> {
        let today = Date()
        
        if let fullRange = fullDateRange {
            // Use fullDateRange but cap at today
            let upperBound = min(fullRange.upperBound, today)
            return fullRange.lowerBound...upperBound
        }
        
        // Fall back to entries-based range
        guard let first = sortedEntries.first?.date,
              let last = sortedEntries.last?.date else {
            return today...today
        }
        
        let upperBound = min(last, today)
        return first...upperBound
    }
    
    // Calculate Y-axis ranges with proper normalization
    private var weightRange: ClosedRange<Double> {
        let weights = sortedEntries.map { convertedWeight($0.weight) }
        guard let min = weights.min(), let max = weights.max() else {
            return 70...80 // Default range
        }
        
        // Ensure minimum range for single data point
        let range = max - min
        if range < 5 {
            let center = (min + max) / 2
            return (center - 5)...(center + 5)
        }
        
        // Add 10% padding
        let padding = range * 0.1
        return (min - padding)...(max + padding)
    }
    
    private var bodyFatRange: ClosedRange<Double> {
        let bodyFats = bodyFatEntries.compactMap { $0.bodyFatPercentage }
        guard let min = bodyFats.min(), let max = bodyFats.max() else {
            return 15...25 // Default range
        }
        
        // Ensure minimum range for single data point
        let range = max - min
        if range < 5 {
            let center = (min + max) / 2
            return (center - 5)...(center + 5)
        }
        
        // Add 10% padding
        let padding = range * 0.1
        return (min - padding)...(max + padding)
    }
    
    // Normalize value to 0-1 range for accurate positioning
    private func normalizeWeight(_ weight: Double) -> Double {
        let range = weightRange.upperBound - weightRange.lowerBound
        return (weight - weightRange.lowerBound) / range
    }
    
    private func normalizeBodyFat(_ bodyFat: Double) -> Double {
        let range = bodyFatRange.upperBound - bodyFatRange.lowerBound
        return (bodyFat - bodyFatRange.lowerBound) / range
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Selected data display
            if let selectedDate = selectedDate {
                HStack(spacing: 20) {
                    Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.headline)
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        if let selectedEntry = selectedEntry {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Weight")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(convertedWeight(selectedEntry.weight), specifier: "%.1f") \(userSettings.settings.weightUnit.symbol)")
                                    .font(.body)
                                    .foregroundColor(.bodyLapseTurquoise)
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
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("No data")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Tap + to add")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .frame(minWidth: 120)
                        }
                    }
                    
                    Button(action: onEditWeight) {
                        Image(systemName: selectedEntry != nil ? "pencil.circle.fill" : "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
            }
            
            // Chart with normalized Y-axes
            HStack(spacing: 0) {
                // Left Y-axis labels for weight
                VStack(alignment: .trailing, spacing: 0) {
                    // Create 4 evenly spaced labels
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
                
                // Main chart area
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                    
                    // Chart content
                    GeometryReader { geometry in
                        let chartWidth = geometry.size.width
                        let chartHeight = geometry.size.height
                        
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
                        if !sortedEntries.isEmpty {
                            // Line
                            if sortedEntries.count > 1 {
                                Path { path in
                                    for (index, entry) in sortedEntries.enumerated() {
                                        let x = xPosition(for: entry.date, in: chartWidth)
                                        let normalizedY = 1 - normalizeWeight(convertedWeight(entry.weight))
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
                            ForEach(sortedEntries) { entry in
                                let x = xPosition(for: entry.date, in: chartWidth)
                                let normalizedY = 1 - normalizeWeight(convertedWeight(entry.weight))
                                let y = chartHeight * normalizedY
                                
                                Circle()
                                    .fill(Color.bodyLapseTurquoise)
                                    .frame(width: sortedEntries.count == 1 ? 10 : 6, 
                                           height: sortedEntries.count == 1 ? 10 : 6)
                                    .position(x: x, y: y)
                            }
                        }
                        
                        // Body fat data
                        if !bodyFatEntries.isEmpty {
                            // Line
                            if bodyFatEntries.count > 1 {
                                Path { path in
                                    for (index, entry) in bodyFatEntries.enumerated() {
                                        if let bodyFat = entry.bodyFatPercentage {
                                            let x = xPosition(for: entry.date, in: chartWidth)
                                            let normalizedY = 1 - normalizeBodyFat(bodyFat)
                                            let y = chartHeight * normalizedY
                                            
                                            if index == 0 {
                                                path.move(to: CGPoint(x: x, y: y))
                                            } else {
                                                path.addLine(to: CGPoint(x: x, y: y))
                                            }
                                        }
                                    }
                                }
                                .stroke(Color.orange, lineWidth: 2)
                            }
                            
                            // Points
                            ForEach(bodyFatEntries) { entry in
                                if let bodyFat = entry.bodyFatPercentage {
                                    let x = xPosition(for: entry.date, in: chartWidth)
                                    let normalizedY = 1 - normalizeBodyFat(bodyFat)
                                    let y = chartHeight * normalizedY
                                    
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: bodyFatEntries.count == 1 ? 10 : 6,
                                               height: bodyFatEntries.count == 1 ? 10 : 6)
                                        .position(x: x, y: y)
                                }
                            }
                        }
                        
                        // Selection indicator
                        if let selectedDate = selectedDate {
                            let x = xPosition(for: selectedDate, in: chartWidth)
                            
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
                                updateSelection(at: location.x, width: chartWidth)
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        isDragging = true
                                        updateSelection(at: value.location.x, width: chartWidth)
                                    }
                                    .onEnded { _ in
                                        isDragging = false
                                    }
                            )
                    }
                    .frame(height: 160)
                    .clipped()
                }
                
                // Right Y-axis labels for body fat
                if !bodyFatEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        // Create 4 evenly spaced labels
                        ForEach(0..<4) { index in
                            let fraction = Double(3 - index) / 3.0
                            let value = bodyFatRange.lowerBound + (bodyFatRange.upperBound - bodyFatRange.lowerBound) * fraction
                            
                            Text("\(value, specifier: "%.1f")%")
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
            // Select the most recent entry by default
            if selectedDate == nil, let lastEntry = sortedEntries.last {
                selectedDate = lastEntry.date
            }
        }
        .onChange(of: entries) { _, newEntries in
            // Update selection when entries change
            let sorted = newEntries.sorted { $0.date < $1.date }
            if let lastEntry = sorted.last {
                selectedDate = lastEntry.date
            }
        }
    }
    
    private func xPosition(for date: Date, in width: CGFloat) -> CGFloat {
        let range = constrainedDateRange
        let totalInterval = range.upperBound.timeIntervalSince(range.lowerBound)
        
        if totalInterval <= 0 {
            return width / 2
        }
        
        let dateInterval = date.timeIntervalSince(range.lowerBound)
        let fraction = dateInterval / totalInterval
        
        // Add small padding on sides (5%)
        return width * 0.05 + (width * 0.9 * CGFloat(fraction))
    }
    
    private func updateSelection(at x: CGFloat, width: CGFloat) {
        let range = constrainedDateRange
        
        // Remove padding calculation
        let fraction = (x - width * 0.05) / (width * 0.9)
        let clampedFraction = max(0, min(1, fraction))
        
        let totalInterval = range.upperBound.timeIntervalSince(range.lowerBound)
        let selectedInterval = totalInterval * Double(clampedFraction)
        let selectedTime = range.lowerBound.addingTimeInterval(selectedInterval)
        
        // Ensure we don't select future dates
        let today = Date()
        let constrainedTime = min(selectedTime, today)
        
        // Snap to nearest data point if close
        let snapThreshold = totalInterval * 0.03 // 3% of range
        
        if let closestEntry = sortedEntries.min(by: { entry1, entry2 in
            abs(entry1.date.timeIntervalSince(constrainedTime)) < abs(entry2.date.timeIntervalSince(constrainedTime))
        }) {
            let distance = abs(closestEntry.date.timeIntervalSince(constrainedTime))
            if distance <= snapThreshold {
                selectedDate = closestEntry.date
            } else {
                selectedDate = constrainedTime
            }
        } else {
            selectedDate = constrainedTime
        }
    }
    
    private var selectedEntry: WeightEntry? {
        guard let selectedDate = selectedDate else { return nil }
        
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
            onEditWeight: {},
            fullDateRange: nil
        )
    }
}