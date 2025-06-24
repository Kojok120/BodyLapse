import SwiftUI
import Charts

@available(iOS 16.0, *)
struct InteractiveWeightChartView: View {
    let entries: [WeightEntry]
    @Binding var selectedDate: Date?
    @StateObject private var userSettings = UserSettingsManager()
    
    @State private var plotWidth: CGFloat = 0
    @State private var isDragging = false
    
    private var sortedEntries: [WeightEntry] {
        entries.sorted { $0.date < $1.date }
    }
    
    private var dateRange: ClosedRange<Date> {
        guard let first = sortedEntries.first?.date,
              let last = sortedEntries.last?.date else {
            let now = Date()
            return now...now
        }
        return first...last
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Selected data display
            if let selectedEntry = selectedEntry {
                HStack(spacing: 30) {
                    VStack(alignment: .leading) {
                        Text("Weight")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(convertedWeight(selectedEntry.weight), specifier: "%.1f") \(userSettings.settings.weightUnit.symbol)")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    
                    if let bodyFat = selectedEntry.bodyFatPercentage {
                        VStack(alignment: .leading) {
                            Text("Body Fat")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(bodyFat, specifier: "%.1f")%")
                                .font(.headline)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Spacer()
                    
                    Text(selectedEntry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
            }
            
            // Chart
            Chart {
                // Weight data
                ForEach(sortedEntries) { entry in
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("Weight", convertedWeight(entry.weight))
                    )
                    .foregroundStyle(Color.blue)
                    .interpolationMethod(.catmullRom)
                    
                    PointMark(
                        x: .value("Date", entry.date),
                        y: .value("Weight", convertedWeight(entry.weight))
                    )
                    .foregroundStyle(Color.blue)
                }
                
                // Body fat data
                ForEach(sortedEntries.filter { $0.bodyFatPercentage != nil }) { entry in
                    if let bodyFat = entry.bodyFatPercentage {
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Body Fat", bodyFat)
                        )
                        .foregroundStyle(Color.orange)
                        .interpolationMethod(.catmullRom)
                        
                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("Body Fat", bodyFat)
                        )
                        .foregroundStyle(Color.orange)
                    }
                }
                
                // Selection indicator
                if let selectedDate = selectedDate {
                    RuleMark(x: .value("Selected", selectedDate))
                        .foregroundStyle(Color.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        .annotation(position: .top) {
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .offset(y: -8)
                        }
                }
            }
            .frame(height: 250)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartBackground { chartProxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            updateSelection(at: location.x, geometry: geometry, chartProxy: chartProxy)
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDragging = true
                                    updateSelection(at: value.location.x, geometry: geometry, chartProxy: chartProxy)
                                }
                                .onEnded { _ in
                                    isDragging = false
                                }
                        )
                }
            }
            .chartLegend {
                HStack(spacing: 20) {
                    Label("Weight", systemImage: "circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    Label("Body Fat", systemImage: "circle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
                .padding(.top, 10)
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(15)
            
            // Photo preview if available
            if let selectedEntry = selectedEntry,
               let photoID = selectedEntry.linkedPhotoID,
               let photo = PhotoStorageService.shared.photos.first(where: { $0.id.uuidString == photoID }),
               let image = PhotoStorageService.shared.loadImage(for: photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(UIColor.separator), lineWidth: 1)
                    )
            }
        }
        .onAppear {
            // Select the most recent entry by default
            if selectedDate == nil, let lastEntry = sortedEntries.last {
                selectedDate = lastEntry.date
            }
        }
    }
    
    private func updateSelection(at x: CGFloat, geometry: GeometryProxy, chartProxy: ChartProxy) {
        guard !sortedEntries.isEmpty else { return }
        
        let xPosition = x - geometry.frame(in: .local).origin.x
        let plotWidth = geometry.size.width
        
        // Calculate the date based on position
        let dateInterval = dateRange.upperBound.timeIntervalSince(dateRange.lowerBound)
        let selectedInterval = (xPosition / plotWidth) * dateInterval
        let selectedTime = dateRange.lowerBound.addingTimeInterval(selectedInterval)
        
        // Find the closest entry
        let closestEntry = sortedEntries.min(by: { entry1, entry2 in
            abs(entry1.date.timeIntervalSince(selectedTime)) < abs(entry2.date.timeIntervalSince(selectedTime))
        })
        
        if let entry = closestEntry {
            selectedDate = entry.date
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
            selectedDate: .constant(nil)
        )
    }
}