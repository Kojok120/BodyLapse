import SwiftUI

#if DEBUG
struct DebugSettingsView: View {
    @StateObject private var userSettings = UserSettingsManager.shared
    @StateObject private var subscriptionManager = SubscriptionManagerService.shared
    @StateObject private var storeManager = StoreManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isLoadingProducts = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    StatusRow(
                        title: "Current Mode",
                        value: StoreManager.debugMode ? "Debug" : "Production",
                        color: StoreManager.debugMode ? .orange : .blue
                    )
                    
                    StatusRow(
                        title: "Subscription Status",
                        value: subscriptionManager.isPremium ? "Premium" : "Free",
                        color: subscriptionManager.isPremium ? .green : .gray
                    )
                } header: {
                    Text("Current Status")
                }
                
                Section {
                    StatusRow(
                        title: "Bundle ID",
                        value: Bundle.main.bundleIdentifier ?? "Unknown",
                        color: .blue
                    )
                    
                    StatusRow(
                        title: "Products Loaded",
                        value: "\(storeManager.products.count)",
                        color: storeManager.products.isEmpty ? .red : .green
                    )
                    
                    if isLoadingProducts {
                        HStack {
                            Text("Loading Products...")
                            Spacer()
                            ProgressView()
                        }
                    }
                    
                    if let error = storeManager.purchaseError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    ForEach(storeManager.products, id: \.id) { product in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                            Text(product.id)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(product.displayPrice)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 2)
                    }
                    
                    Button("Reload Products") {
                        Task {
                            isLoadingProducts = true
                            await storeManager.loadProducts()
                            isLoadingProducts = false
                        }
                    }
                    .foregroundColor(.blue)
                } header: {
                    Text("StoreKit Diagnostics")
                } footer: {
                    Text("Shows StoreKit configuration status and loaded products")
                        .font(.caption)
                }
                
                Section {
                    QuickActionButton(
                        title: "Test as Free User",
                        icon: "person",
                        color: .gray
                    ) {
                        setDebugMode(premium: false)
                    }
                    
                    QuickActionButton(
                        title: "Test as Premium User",
                        icon: "crown.fill",
                        color: .yellow
                    ) {
                        setDebugMode(premium: true)
                    }
                    
                    QuickActionButton(
                        title: "Use Real Purchase Status",
                        icon: "purchased.circle",
                        color: .blue
                    ) {
                        resetToProduction()
                    }
                } header: {
                    Text("Quick Actions")
                } footer: {
                    Text("Debug mode lets you test features without making real purchases")
                        .font(.caption)
                }
                
                Section {
                    QuickActionButton(
                        title: "Add Sample Weight Entry",
                        icon: "plus.circle.fill",
                        color: .blue
                    ) {
                        Task {
                            let entry = WeightEntry(
                                date: Date(),
                                weight: 75.5,
                                bodyFatPercentage: 18.5,
                                linkedPhotoID: nil
                            )
                            try? await WeightStorageService.shared.saveEntry(entry)
                            print("[Debug] Added sample weight entry")
                        }
                    }
                    
                    QuickActionButton(
                        title: "Add 7 Days of Data",
                        icon: "7.circle.fill",
                        color: .green
                    ) {
                        Task {
                            let calendar = Calendar.current
                            for i in 0..<7 {
                                if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                                    let weight = 75.0 + Double.random(in: -2...2)
                                    let bodyFat = 18.0 + Double.random(in: -1...1)
                                    let entry = WeightEntry(
                                        date: date,
                                        weight: weight,
                                        bodyFatPercentage: bodyFat,
                                        linkedPhotoID: nil
                                    )
                                    try? await WeightStorageService.shared.saveEntry(entry)
                                }
                            }
                            print("[Debug] Added 7 sample weight entries")
                        }
                    }
                    
                    QuickActionButton(
                        title: "Add 30 Days of Data",
                        icon: "30.circle.fill",
                        color: .purple
                    ) {
                        Task {
                            let calendar = Calendar.current
                            for i in 0..<30 {
                                if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                                    let weight = 75.0 + Double.random(in: -3...1) - Double(i) * 0.05 // Gradual weight loss
                                    let bodyFat = 20.0 + Double.random(in: -1...1) - Double(i) * 0.03 // Gradual fat loss
                                    let entry = WeightEntry(
                                        date: date,
                                        weight: weight,
                                        bodyFatPercentage: bodyFat,
                                        linkedPhotoID: nil
                                    )
                                    try? await WeightStorageService.shared.saveEntry(entry)
                                }
                            }
                            print("[Debug] Added 30 sample weight entries")
                        }
                    }
                    
                    QuickActionButton(
                        title: "Clear All Weight Data",
                        icon: "trash.fill",
                        color: .red
                    ) {
                        Task {
                            // Clear by saving empty array
                            let documentsDirectory = FileManager.default.urls(
                                for: .documentDirectory,
                                in: .userDomainMask
                            ).first!
                            let weightsFile = documentsDirectory
                                .appendingPathComponent("WeightData")
                                .appendingPathComponent("entries.json")
                            
                            let encoder = JSONEncoder()
                            encoder.dateEncodingStrategy = .iso8601
                            if let data = try? encoder.encode([WeightEntry]()) {
                                try? data.write(to: weightsFile, options: .atomic)
                                print("[Debug] Cleared all weight data")
                            }
                        }
                    }
                } header: {
                    Text("Debug Weight Data")
                } footer: {
                    Text("Use these actions to test weight tracking features")
                        .font(.caption)
                }
            }
            .navigationTitle("Debug Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func setDebugMode(premium: Bool) {
        StoreManager.debugMode = true
        StoreManager.debugPremiumStatus = premium
        subscriptionManager.setDebugPremiumStatus(premium)
    }
    
    private func resetToProduction() {
        StoreManager.debugMode = false
        Task {
            await subscriptionManager.refreshSubscriptionStatus()
        }
    }
}

// MARK: - Components
private struct StatusRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

private struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct DebugSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        DebugSettingsView()
    }
}
#endif