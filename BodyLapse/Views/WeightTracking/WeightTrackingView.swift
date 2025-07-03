import SwiftUI
import Charts

struct WeightTrackingView: View {
    @StateObject private var viewModel = WeightTrackingViewModel()
    @State private var showingAddEntry = false
    @State private var selectedTimeRange = WeightTimeRange.month
    @State private var selectedDate: Date? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Time range picker
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(WeightTimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            if viewModel.weightEntries.isEmpty {
                // Empty state
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 80))
                        .foregroundColor(.gray.opacity(0.3))
                    
                    Text(NSLocalizedString("weight.no_data_yet", comment: "No weight data message"))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(NSLocalizedString("weight.start_tracking_message", comment: "Start tracking message"))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)
                    
                    Button(action: { showingAddEntry = true }) {
                        Label(NSLocalizedString("weight.add_first_entry", comment: "Add first entry button"), systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .cornerRadius(25)
                    }
                    .padding(.top, 10)
                    
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Interactive combined chart
                        if !viewModel.weightEntries.isEmpty {
                            if #available(iOS 16.0, *) {
                                InteractiveWeightChartView(
                                    entries: viewModel.filteredEntries(for: selectedTimeRange),
                                    selectedDate: $selectedDate,
                                    currentPhoto: nil,
                                    onEditWeight: {},
                                    fullDateRange: nil
                                )
                                .padding(.horizontal)
                            } else {
                                // Fallback for iOS < 16
                                VStack(spacing: 20) {
                                    WeightChartView(
                                        entries: viewModel.filteredEntries(for: selectedTimeRange),
                                        title: "Weight Progress"
                                    )
                                    .frame(height: 250)
                                    
                                    if viewModel.hasBodyFatData {
                                        BodyFatChartView(
                                            entries: viewModel.filteredEntries(for: selectedTimeRange),
                                            title: "Body Fat Progress"
                                        )
                                        .frame(height: 250)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Recent entries
                        RecentEntriesView(viewModel: viewModel)
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("nav.weight_tracking".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddEntry = true }) {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingAddEntry) {
            AddWeightEntryView(viewModel: viewModel) {
                showingAddEntry = false
            }
        }
        .onAppear {
            viewModel.loadEntries()
        }
    }
}

// MARK: - Current Stats View
struct CurrentStatsView: View {
    @ObservedObject var viewModel: WeightTrackingViewModel
    
    var body: some View {
        HStack(spacing: 20) {
            StatCard(
                title: "Current Weight",
                value: viewModel.formattedCurrentWeight,
                unit: viewModel.weightUnit.symbol
            )
            
            if let bodyFat = viewModel.currentBodyFat {
                StatCard(
                    title: "Body Fat",
                    value: String(format: "%.1f", bodyFat),
                    unit: "%"
                )
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .bottom, spacing: 4) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                Text(unit)
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(15)
    }
}


// MARK: - Weight Chart View
struct WeightChartView: View {
    let entries: [WeightEntry]
    let title: String
    @StateObject private var userSettings = UserSettingsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            
            if #available(iOS 16.0, *) {
                Chart(entries) { entry in
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("Weight", convertedWeight(entry.weight))
                    )
                    .foregroundStyle(Color.accentColor)
                    .interpolationMethod(.catmullRom)
                    
                    PointMark(
                        x: .value("Date", entry.date),
                        y: .value("Weight", convertedWeight(entry.weight))
                    )
                    .foregroundStyle(Color.accentColor)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(15)
            }
        }
    }
    
    private func convertedWeight(_ weight: Double) -> Double {
        userSettings.settings.weightUnit == .kg ? weight : weight * 2.20462
    }
}

// MARK: - Body Fat Chart View
struct BodyFatChartView: View {
    let entries: [WeightEntry]
    let title: String
    
    var validEntries: [WeightEntry] {
        entries.filter { $0.bodyFatPercentage != nil }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            
            if #available(iOS 16.0, *), !validEntries.isEmpty {
                Chart(validEntries) { entry in
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
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(15)
            }
        }
    }
}

// MARK: - Recent Entries View
struct RecentEntriesView: View {
    @ObservedObject var viewModel: WeightTrackingViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(NSLocalizedString("weight.recent_entries", comment: "Recent entries header"))
                .font(.headline)
            
            ForEach(viewModel.recentEntries.prefix(5)) { entry in
                WeightEntryRow(entry: entry, weightUnit: viewModel.weightUnit)
            }
        }
    }
}

// MARK: - Weight Entry Row
struct WeightEntryRow: View {
    let entry: WeightEntry
    let weightUnit: UserSettings.WeightUnit
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 10) {
                    Text("\(convertedWeight, specifier: "%.1f") \(weightUnit.symbol)")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    if let bodyFat = entry.bodyFatPercentage {
                        Text("\(bodyFat, specifier: "%.1f")%")
                            .font(.body)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            if entry.linkedPhotoID != nil {
                Image(systemName: "camera.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .cornerRadius(10)
    }
    
    private var convertedWeight: Double {
        weightUnit == .kg ? entry.weight : entry.weight * 2.20462
    }
}

// MARK: - Add Weight Entry View
struct AddWeightEntryView: View {
    @ObservedObject var viewModel: WeightTrackingViewModel
    let onDismiss: () -> Void
    
    @State private var weight: String = ""
    @State private var bodyFat: String = ""
    @State private var selectedDate = Date()
    @State private var linkToTodaysPhoto = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Weight") {
                    HStack {
                        TextField(NSLocalizedString("weight.weight", comment: "Weight placeholder"), text: $weight)
                            .keyboardType(.decimalPad)
                        Text(viewModel.weightUnit.symbol)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Body Fat (Optional)") {
                    HStack {
                        TextField(NSLocalizedString("weight.body_fat", comment: "Body fat placeholder"), text: $bodyFat)
                            .keyboardType(.decimalPad)
                        Text("%")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Date") {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                }
                
                if PhotoStorageService.shared.hasPhoto(for: selectedDate) {
                    Section {
                        Toggle("Link to today's photo", isOn: $linkToTodaysPhoto)
                    }
                }
            }
            .navigationTitle("nav.add_entry".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("common.cancel", comment: "Cancel button")) {
                        dismiss()
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("common.save", comment: "Save button")) {
                        saveEntry()
                    }
                    .disabled(weight.isEmpty)
                }
            }
        }
    }
    
    private func saveEntry() {
        guard let weightValue = Double(weight) else { return }
        
        let bodyFatValue = bodyFat.isEmpty ? nil : Double(bodyFat)
        let photoID = linkToTodaysPhoto ? PhotoStorageService.shared.getPhotoID(for: selectedDate) : nil
        
        viewModel.addEntry(
            weight: viewModel.weightUnit == .kg ? weightValue : weightValue / 2.20462,
            bodyFat: bodyFatValue,
            date: selectedDate,
            linkedPhotoID: photoID
        )
        
        dismiss()
        onDismiss()
    }
}

struct WeightTrackingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WeightTrackingView()
        }
    }
}