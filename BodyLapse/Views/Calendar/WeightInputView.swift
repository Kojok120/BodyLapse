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
            if let photo = photo {
                if let weight = photo.weight {
                    weightText = String(format: "%.1f", convertWeight(weight))
                }
                if let bodyFat = photo.bodyFatPercentage {
                    bodyFatText = String(format: "%.1f", bodyFat)
                }
                
                // If no weight data and HealthKit is enabled, try to fetch it
                if photo.weight == nil && subscriptionManager.isPremium && userSettings.settings.healthKitEnabled {
                    fetchHealthKitData()
                }
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
    
    private func convertWeight(_ kg: Double) -> Double {
        userSettings.settings.weightUnit == .kg ? kg : kg * 2.20462
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        // Check current language and set appropriate format
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
        isLoadingHealthData = true
        
        // Fetch weight data from HealthKit
        HealthKitService.shared.fetchLatestWeight { weightKg, error in
            DispatchQueue.main.async {
                if let weightKg = weightKg {
                    self.weightText = String(format: "%.1f", self.convertWeight(weightKg))
                }
                
                // Also fetch body fat
                HealthKitService.shared.fetchLatestBodyFatPercentage { bodyFatPercent, error in
                    DispatchQueue.main.async {
                        if let bodyFatPercent = bodyFatPercent {
                            self.bodyFatText = String(format: "%.1f", bodyFatPercent)
                        }
                        self.isLoadingHealthData = false
                    }
                }
            }
        }
    }
}