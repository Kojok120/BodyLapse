import SwiftUI

struct WeightInputSheet: View {
    @Binding var weight: Double?
    @Binding var bodyFat: Double?
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @State private var weightText = ""
    @State private var bodyFatText = ""
    @StateObject private var userSettings = UserSettingsManager()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "scalemass")
                        .font(.system(size: 50))
                        .foregroundColor(.accentColor)
                    
                    Text("Track Your Progress")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Add your current measurements")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 30)
                .padding(.bottom, 40)
                
                // Input fields
                VStack(spacing: 25) {
                    // Weight input
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Weight", systemImage: "scalemass")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            TextField("Enter weight", text: $weightText)
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
                        Label("Body Fat % (Optional)", systemImage: "percent")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            TextField("Enter body fat", text: $bodyFatText)
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
                        Text("Save Photo")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentColor)
                            .cornerRadius(12)
                    }
                    .disabled(weightText.isEmpty)
                    
                    Button(action: skipAndSave) {
                        Text("Skip & Save Photo")
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
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let w = weight {
                weightText = String(format: "%.1f", convertWeight(w))
            }
            if let bf = bodyFat {
                bodyFatText = String(format: "%.1f", bf)
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