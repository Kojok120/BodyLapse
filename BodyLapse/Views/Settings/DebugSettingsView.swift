import SwiftUI

#if DEBUG
struct DebugSettingsView: View {
    @StateObject private var userSettings = UserSettingsManager()
    @Environment(\.dismiss) private var dismiss
    
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
                        value: userSettings.settings.isPremium ? "Premium" : "Free",
                        color: userSettings.settings.isPremium ? .green : .gray
                    )
                } header: {
                    Text("Current Status")
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
        userSettings.settings.isPremium = premium
        NotificationCenter.default.post(name: .premiumStatusChanged, object: nil)
    }
    
    private func resetToProduction() {
        StoreManager.debugMode = false
        Task {
            await userSettings.syncPremiumStatus()
            NotificationCenter.default.post(name: .premiumStatusChanged, object: nil)
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