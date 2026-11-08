import SwiftUI

struct WeightInputView: View {
    @Binding var photo: Photo?
    let selectedDate: Date
    /// 体重 (kg) と体脂肪率を渡す。体重は必須。
    let onSave: (Double, Double?) -> Void
    /// この日の体重と体脂肪率を消す。写真は残す。
    let onDelete: () -> Void

    private enum Field: Hashable {
        case weight
        case bodyFat
    }

    @State private var weightText = ""
    @State private var bodyFatText = ""
    @State private var hasExistingData = false
    @State private var showingDeleteConfirmation = false
    @FocusState private var focusedField: Field?
    @StateObject private var userSettings = UserSettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isLoadingHealthData = false

    private var weightUnit: UserSettings.WeightUnit {
        userSettings.settings.weightUnit
    }

    private var parsedWeightKg: Double? {
        MeasurementInput.weightKg(from: weightText, unit: weightUnit)
    }

    private var parsedBodyFat: Double? {
        MeasurementInput.bodyFat(from: bodyFatText)
    }

    private var isBodyFatEmpty: Bool {
        bodyFatText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isWeightEmpty: Bool {
        weightText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSave: Bool {
        parsedWeightKg != nil && (isBodyFatEmpty || parsedBodyFat != nil)
    }

    private var weightRangeMessage: String {
        let range = MeasurementInput.weightRangeKg
        let lower = MeasurementInput.displayWeight(kg: range.lowerBound, unit: weightUnit).rounded(.up)
        let upper = MeasurementInput.displayWeight(kg: range.upperBound, unit: weightUnit).rounded(.down)
        return "calendar.weight_invalid_range".localized(with: Int(lower), Int(upper), weightUnit.symbol)
    }

    private var bodyFatRangeMessage: String {
        let range = MeasurementInput.bodyFatRange
        return "calendar.body_fat_invalid_range".localized(with: Int(range.lowerBound), Int(range.upperBound))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    inputFields
                    healthKitSection

                    if hasExistingData {
                        Button(role: .destructive) {
                            focusedField = nil
                            showingDeleteConfirmation = true
                        } label: {
                            Text("calendar.delete_measurements".localized)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .padding(.horizontal, 30)
                        .padding(.top, 24)
                    }
                }
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save".localized, action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("common.done".localized) {
                        focusedField = nil
                    }
                }
            }
            .confirmationDialog(
                "calendar.delete_measurements_confirm".localized,
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("common.delete".localized, role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("common.cancel".localized, role: .cancel) {}
            }
        }
        .onAppear {
            Task {
                await loadInitialData()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "scalemass")
                .font(.system(size: 50))
                .foregroundColor(.accentColor)

            Text("calendar.update_measurements".localized)
                .font(.title2)
                .fontWeight(.bold)

            Text(formatDate(photo?.captureDate ?? selectedDate))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 30)
        .padding(.bottom, 32)
    }

    private var inputFields: some View {
        VStack(spacing: 25) {
            // 体重
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("calendar.weight".localized, systemImage: "scalemass")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    if isLoadingHealthData {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }

                HStack {
                    TextField("calendar.enter_weight".localized, text: $weightText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .focused($focusedField, equals: .weight)

                    Text(weightUnit.symbol)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                if !isWeightEmpty && parsedWeightKg == nil {
                    Text(weightRangeMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            // 体脂肪率
            VStack(alignment: .leading, spacing: 8) {
                Label("calendar.body_fat_optional".localized, systemImage: "percent")
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack {
                    TextField("calendar.enter_body_fat".localized, text: $bodyFatText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .focused($focusedField, equals: .bodyFat)

                    Text("unit.percent".localized)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                if !isBodyFatEmpty && parsedBodyFat == nil {
                    Text(bodyFatRangeMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 30)
    }

    // ヘルスケア連携は全ユーザーが使える
    private var healthKitSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                    .foregroundColor(.red)
                Text("settings.apple_health_integration".localized)
                    .font(.headline)
                Spacer()
            }

            Toggle(isOn: $userSettings.settings.healthKitEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("settings.sync_health".localized)
                        .font(.subheadline)
                    Text("settings.auto_import".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: userSettings.settings.healthKitEnabled) { _, newValue in
                if newValue {
                    requestHealthKitPermission()
                }
            }

            if userSettings.settings.healthKitEnabled {
                Button(action: syncHealthData) {
                    HStack {
                        if isLoadingHealthData {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text("calendar.sync_today_data".localized)
                    }
                }
                .disabled(isLoadingHealthData)
            }
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal, 30)
        .padding(.top, 20)
    }

    private func save() {
        guard let weight = parsedWeightKg else { return }
        let bodyFat = isBodyFatEmpty ? nil : parsedBodyFat
        guard isBodyFatEmpty || bodyFat != nil else { return }

        onSave(weight, bodyFat)

        // ヘルスケアへも書き込む (連携がオンのとき)
        if userSettings.settings.healthKitEnabled {
            let saveDate = photo?.captureDate ?? selectedDate
            HealthKitService.shared.saveWeight(weight, date: saveDate) { _, _ in }
            if let bf = bodyFat {
                HealthKitService.shared.saveBodyFatPercentage(bf, date: saveDate) { _, _ in }
            }
        }

        dismiss()
    }

    private func loadInitialData() async {
        let targetDate = photo?.captureDate ?? selectedDate
        
        // First, try to get data from the Photo object
        if let photo = photo {
            if let weight = photo.weight, weight > 0 {
                await MainActor.run {
                    weightText = MeasurementInput.inputText(convertWeight(weight))
                    hasExistingData = true
                }
            }
            if let bodyFat = photo.bodyFatPercentage {
                await MainActor.run {
                    bodyFatText = MeasurementInput.inputText(bodyFat)
                    hasExistingData = true
                }
            }
        }
        
        // If no data in Photo object, try to get from WeightStorageService
        if weightText.isEmpty || bodyFatText.isEmpty {
            do {
                if let weightEntry = try await WeightStorageService.shared.getEntry(for: targetDate) {
                    await MainActor.run {
                        hasExistingData = true
                        if weightText.isEmpty && weightEntry.weight > 0 {
                            weightText = MeasurementInput.inputText(convertWeight(weightEntry.weight))
                        }
                        if bodyFatText.isEmpty, let bodyFat = weightEntry.bodyFatPercentage {
                            bodyFatText = MeasurementInput.inputText(bodyFat)
                        }
                    }
                }
            } catch {
                print("Failed to load weight entry: \(error)")
            }
        }
        
        // If still no weight data and HealthKit is enabled, try to fetch it
        if weightText.isEmpty && userSettings.settings.healthKitEnabled {
            await MainActor.run {
                fetchHealthKitData()
            }
        }
    }
    
    private func convertWeight(_ kg: Double) -> Double {
        MeasurementInput.displayWeight(kg: kg, unit: weightUnit)
    }
    
    private func formatDate(_ date: Date) -> String {
        AppDateFormat.medium(date)
    }
    
    private func fetchHealthKitData() {
        // Use the same logic as syncHealthData
        syncHealthData()
    }
    
    private func requestHealthKitPermission() {
        print("Requesting HealthKit permission...")
        HealthKitService.shared.requestAuthorization { success, error in
            DispatchQueue.main.async {
                print("HealthKit authorization result: success=\(success), error=\(error?.localizedDescription ?? "none")")
                
                if success {
                    self.userSettings.settings.healthKitEnabled = true
                    print("HealthKit permission granted, performing initial sync...")
                    // Perform initial sync after permission is granted
                    self.syncHealthData()
                } else {
                    self.userSettings.settings.healthKitEnabled = false
                    print("HealthKit permission denied or failed")
                    if let error = error {
                        print("HealthKit authorization failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func syncHealthData() {
        print("syncHealthData called - healthKitEnabled: \(userSettings.settings.healthKitEnabled)")

        guard userSettings.settings.healthKitEnabled else {
            print("Sync cancelled - health kit not enabled")
            return
        }
        
        isLoadingHealthData = true
        print("Starting HealthKit data sync...")
        
        // Get the target date (selected date or photo date)
        let targetDate = photo?.captureDate ?? selectedDate
        
        // Fetch weight data for only the selected date
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: targetDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        print("Fetching HealthKit data for specific date: \(startOfDay) to \(endOfDay)")
        
        HealthKitService.shared.fetchWeightData(from: startOfDay, to: endOfDay) { entries, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching weight data: \(error.localizedDescription)")
                    self.isLoadingHealthData = false
                    return
                }
                
                print("Fetched \(entries.count) weight entries for the selected date")
                
                // Find the entry for the exact date only
                let sameDayEntry = entries.first { entry in
                    calendar.isDate(entry.date, inSameDayAs: targetDate)
                }
                
                if let entry = sameDayEntry {
                    print("Found entry for the selected date: weight=\(entry.weight) kg, bodyFat=\(entry.bodyFatPercentage ?? 0)%, date=\(entry.date)")
                    
                    // Update the text fields with the found data
                    self.weightText = MeasurementInput.inputText(self.convertWeight(entry.weight))
                    
                    if let bodyFat = entry.bodyFatPercentage {
                        self.bodyFatText = MeasurementInput.inputText(bodyFat)
                    }
                } else {
                    print("No weight data found for the selected date")
                    // Don't update the text fields - leave them as they are
                }
                
                self.isLoadingHealthData = false
                print("HealthKit sync completed")
            }
        }
    }
}