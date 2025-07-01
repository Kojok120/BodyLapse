import SwiftUI

struct WeightInputSheet: View {
    @Binding var weight: Double?
    @Binding var bodyFat: Double?
    let onSave: () -> Void
    let onCancel: () -> Void
    
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
                    
                    Text("weight.track_progress".localized)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("weight.add_measurements".localized)
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
                            Label("weight.weight".localized, systemImage: "scalemass")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if isLoadingHealthData {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        
                        HStack {
                            TextField("weight.enter_weight".localized, text: $weightText)
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
                            TextField("weight.enter_body_fat".localized, text: $bodyFatText)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .font(.title3)
                            
                            Text("%")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 15) {
                    Button(action: saveAndDismiss) {
                        Text("weight.save_photo".localized)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentColor)
                            .cornerRadius(12)
                    }
                    .disabled(weightText.isEmpty)
                    
                    Button(action: skipAndSave) {
                        Text("weight.skip_save".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // First set any existing values
            if let w = weight {
                weightText = String(format: "%.1f", convertWeight(w))
            }
            if let bf = bodyFat {
                bodyFatText = String(format: "%.1f", bf)
            }
            
            // Then try to fetch from HealthKit if enabled and no values set
            if subscriptionManager.isPremium && userSettings.settings.healthKitEnabled && weight == nil {
                fetchHealthKitData()
            }
        }
    }
    
    private func saveAndDismiss() {
        if let weightValue = Double(weightText) {
            // Convert to kg if needed
            weight = userSettings.settings.weightUnit == .kg ? weightValue : weightValue / 2.20462
        }
        
        if !bodyFatText.isEmpty, let bodyFatValue = Double(bodyFatText) {
            bodyFat = bodyFatValue
        }
        
        // Also save to weight tracking
        if let w = weight {
            let entry = WeightEntry(
                date: Date(),
                weight: w,
                bodyFatPercentage: bodyFat,
                linkedPhotoID: nil
            )
            Task {
                try? await WeightStorageService.shared.saveEntry(entry)
            }
            
            // Save to HealthKit if enabled
            if subscriptionManager.isPremium && userSettings.settings.healthKitEnabled {
                HealthKitService.shared.saveWeight(w, date: Date()) { _, _ in }
                if let bf = bodyFat {
                    HealthKitService.shared.saveBodyFatPercentage(bf, date: Date()) { _, _ in }
                }
            }
        }
        
        onSave()
        dismiss()
    }
    
    private func skipAndSave() {
        weight = nil
        bodyFat = nil
        onSave()
        dismiss()
    }
    
    private func convertWeight(_ kg: Double) -> Double {
        userSettings.settings.weightUnit == .kg ? kg : kg * 2.20462
    }
    
    private func fetchHealthKitData() {
        isLoadingHealthData = true
        
        // Get today's start date
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        // Fetch weight data from HealthKit
        HealthKitService.shared.fetchLatestWeight { weightKg, error in
            DispatchQueue.main.async {
                if let weightKg = weightKg {
                    self.weight = weightKg
                    self.weightText = String(format: "%.1f", self.convertWeight(weightKg))
                }
                
                // Also fetch body fat
                HealthKitService.shared.fetchLatestBodyFatPercentage { bodyFatPercent, error in
                    DispatchQueue.main.async {
                        if let bodyFatPercent = bodyFatPercent {
                            self.bodyFat = bodyFatPercent
                            self.bodyFatText = String(format: "%.1f", bodyFatPercent)
                        }
                        self.isLoadingHealthData = false
                    }
                }
            }
        }
    }
}

struct WeightInputSheet_Previews: PreviewProvider {
    static var previews: some View {
        WeightInputSheet(
            weight: .constant(nil),
            bodyFat: .constant(nil),
            onSave: {},
            onCancel: {}
        )
    }
}