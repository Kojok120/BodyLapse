import SwiftUI

struct WeightInputView: View {
    @Binding var photo: Photo?
    let selectedDate: Date
    let onSave: (Double?, Double?) -> Void
    
    @State private var weightText = ""
    @State private var bodyFatText = ""
    @StateObject private var userSettings = UserSettingsManager.shared
    @StateObject private var subscriptionManager = SubscriptionManagerService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isLoadingHealthData = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
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
                .padding(.bottom, 40)
                
                // Input fields
                VStack(spacing: 25) {
                    // Weight input
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
                            
                            Text(userSettings.settings.weightUnit.symbol)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Body fat input
                    VStack(alignment: .leading, spacing: 8) {
                        Label("calendar.body_fat_optional".localized, systemImage: "percent")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            TextField("calendar.enter_body_fat".localized, text: $bodyFatText)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .font(.title3)
                            
                            Text("unit.percent".localized)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 30)
                
                // HealthKit Integration Section
                if subscriptionManager.isPremium {
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
                            } else {
                                // When turning off, just update the setting
                                userSettings.settings.healthKitEnabled = false
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
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 15) {
                    Button(action: save) {
                        Text("common.save".localized)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentColor)
                            .cornerRadius(12)
                    }
                    .disabled(weightText.isEmpty)
                    
                    if photo?.weight != nil || photo?.bodyFatPercentage != nil {
                        Button(action: clear) {
                            Text("calendar.clear_data".localized)
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await loadInitialData()
            }
            
            // Debug: Check actual HealthKit authorization status
            if subscriptionManager.isPremium {
                let isAuthorized = HealthKitService.shared.isAuthorized()
                print("HealthKit authorization status: \(isAuthorized)")
                print("Settings healthKitEnabled: \(userSettings.settings.healthKitEnabled)")
            }
        }
    }
    
    private func save() {
        var weight: Double? = nil
        var bodyFat: Double? = nil
        
        if let weightValue = Double(weightText) {
            // Convert to kg if needed
            weight = userSettings.settings.weightUnit == .kg ? weightValue : weightValue / 2.20462
        }
        
        if !bodyFatText.isEmpty, let bodyFatValue = Double(bodyFatText) {
            bodyFat = bodyFatValue
        }
        
        onSave(weight, bodyFat)
        
        // Save to HealthKit if enabled
        if subscriptionManager.isPremium && userSettings.settings.healthKitEnabled {
            let saveDate = photo?.captureDate ?? selectedDate
            if let w = weight {
                HealthKitService.shared.saveWeight(w, date: saveDate) { _, _ in }
            }
            if let bf = bodyFat {
                HealthKitService.shared.saveBodyFatPercentage(bf, date: saveDate) { _, _ in }
            }
        }
        
        dismiss()
    }
    
    private func clear() {
        onSave(nil, nil)
        dismiss()
    }
    
    private func loadInitialData() async {
        let targetDate = photo?.captureDate ?? selectedDate
        
        // First, try to get data from the Photo object
        if let photo = photo {
            if let weight = photo.weight {
                await MainActor.run {
                    weightText = String(format: "%.1f", convertWeight(weight))
                }
            }
            if let bodyFat = photo.bodyFatPercentage {
                await MainActor.run {
                    bodyFatText = String(format: "%.1f", bodyFat)
                }
            }
        }
        
        // If no data in Photo object, try to get from WeightStorageService
        if weightText.isEmpty || bodyFatText.isEmpty {
            do {
                if let weightEntry = try await WeightStorageService.shared.getEntry(for: targetDate) {
                    await MainActor.run {
                        if weightText.isEmpty && weightEntry.weight > 0 {
                            weightText = String(format: "%.1f", convertWeight(weightEntry.weight))
                        }
                        if bodyFatText.isEmpty, let bodyFat = weightEntry.bodyFatPercentage {
                            bodyFatText = String(format: "%.1f", bodyFat)
                        }
                    }
                }
            } catch {
                print("Failed to load weight entry: \(error)")
            }
        }
        
        // If still no weight data and HealthKit is enabled, try to fetch it
        if weightText.isEmpty && subscriptionManager.isPremium && userSettings.settings.healthKitEnabled {
            await MainActor.run {
                fetchHealthKitData()
            }
        }
    }
    
    private func convertWeight(_ kg: Double) -> Double {
        userSettings.settings.weightUnit == .kg ? kg : kg * 2.20462
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        // 現在の言語を確認して適切なフォーマットを設定
        let currentLanguage = LanguageManager.shared.currentLanguage
        switch currentLanguage {
        case "ja":
            formatter.dateFormat = "yyyy/MM/dd"
        case "ko":
            formatter.dateFormat = "yyyy.MM.dd"
        default:
            formatter.dateFormat = "MMM d, yyyy"
        }
        
        return formatter.string(from: date)
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
        print("syncHealthData called - isPremium: \(subscriptionManager.isPremium), healthKitEnabled: \(userSettings.settings.healthKitEnabled)")
        
        guard subscriptionManager.isPremium && userSettings.settings.healthKitEnabled else {
            print("Sync cancelled - not premium or health kit not enabled")
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
                    self.weightText = String(format: "%.1f", self.convertWeight(entry.weight))
                    
                    if let bodyFat = entry.bodyFatPercentage {
                        self.bodyFatText = String(format: "%.1f", bodyFat)
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