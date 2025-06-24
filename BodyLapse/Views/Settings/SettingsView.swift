import SwiftUI

struct SettingsView: View {
    @StateObject private var userSettings = UserSettingsManager.shared
    @State private var showingAbout = false
    @State private var showingPremiumUpgrade = false
    @State private var showingAppLockSettings = false
    @State private var showingNotificationPermissionAlert = false
    #if DEBUG
    @State private var showingDebugSettings = false
    #endif
    
    var body: some View {
        NavigationView {
            Form {
                Section("Photo Settings") {
                    Toggle("Show Body Guidelines", isOn: $userSettings.settings.showBodyGuidelines)
                    
                    if GuidelineStorageService.shared.hasGuideline() {
                        Button(action: {
                            GuidelineStorageService.shared.deleteGuideline()
                        }) {
                            Label("Reset Body Guideline", systemImage: "arrow.uturn.backward")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Picker("Weight Unit", selection: $userSettings.settings.weightUnit) {
                        ForEach(UserSettings.WeightUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                }
                
                Section("Security") {
                    Toggle("App Lock", isOn: $userSettings.settings.isAppLockEnabled)
                    
                    if userSettings.settings.isAppLockEnabled {
                        HStack {
                            Text("Lock Method")
                            Spacer()
                            Text(userSettings.settings.appLockMethod.rawValue)
                                .foregroundColor(.secondary)
                        }
                        .onTapGesture {
                            showingAppLockSettings = true
                        }
                        
                        if userSettings.settings.appLockMethod == .passcode {
                            NavigationLink(destination: PasscodeSettingsView()) {
                                Label("Change Passcode", systemImage: "number")
                            }
                        }
                    }
                }
                
                Section("Reminders") {
                    Toggle("Daily Reminder", isOn: $userSettings.settings.reminderEnabled)
                        .onChange(of: userSettings.settings.reminderEnabled) { newValue in
                            if newValue {
                                // Request permission when enabling reminders
                                NotificationService.shared.requestNotificationPermission { granted in
                                    if !granted {
                                        userSettings.settings.reminderEnabled = false
                                        showingNotificationPermissionAlert = true
                                    }
                                }
                            }
                        }
                    
                    if userSettings.settings.reminderEnabled {
                        DatePicker("Reminder Time",
                                   selection: $userSettings.settings.reminderTime,
                                   displayedComponents: .hourAndMinute)
                    }
                }
                
                Section("Premium Features") {
                    if userSettings.settings.isPremium {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                            Text("Premium Active")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button(action: { showingPremiumUpgrade = true }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Upgrade to Premium")
                                        .font(.headline)
                                    Text("Remove ads, watermark & track weight")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("$4.99/mo")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
                
                Section(header: Text("Data")) {
                    NavigationLink(destination: ExportView()) {
                        Label("Export Photos", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(role: .destructive) {
                        // TODO: Implement data clearing logic
                    } label: {
                        Label("Clear All Data", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
                
                Section("About") {
                    Button(action: { showingAbout = true }) {
                        HStack {
                            Text("About BodyLapse")
                            Spacer()
                            Text("v1.0.0")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://example.com/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    
                    Link(destination: URL(string: "https://example.com/terms")!) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                }
                
                #if DEBUG
                Section("Developer") {
                    Button(action: { showingDebugSettings = true }) {
                        Label("Debug Settings", systemImage: "wrench.and.screwdriver")
                    }
                }
                #endif
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingPremiumUpgrade) {
                PremiumView()
            }
            #if DEBUG
            .sheet(isPresented: $showingDebugSettings) {
                DebugSettingsView()
            }
            #endif
            .actionSheet(isPresented: $showingAppLockSettings) {
                ActionSheet(
                    title: Text("Select Lock Method"),
                    buttons: [
                        .default(Text(UserSettings.AppLockMethod.biometric.rawValue)) {
                            userSettings.settings.appLockMethod = .biometric
                        },
                        .default(Text(UserSettings.AppLockMethod.passcode.rawValue)) {
                            userSettings.settings.appLockMethod = .passcode
                        },
                        .cancel()
                    ]
                )
            }
            .alert("Notification Permission Required", isPresented: $showingNotificationPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable notifications in Settings to receive daily photo reminders.")
            }
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)
                
                Text("BodyLapse")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Track your fitness journey")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 15) {
                    FeatureRow(icon: "camera.fill", text: "Daily progress photos")
                    FeatureRow(icon: "calendar", text: "Visual progress calendar")
                    FeatureRow(icon: "video.fill", text: "Create time-lapse videos")
                    FeatureRow(icon: "lock.fill", text: "100% private & secure")
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(15)
                .padding(.horizontal)
                
                Spacer()
                
                Text("Made with ❤️ for fitness enthusiasts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("About")
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
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

struct PremiumUpgradeView: View {
    let userSettings: UserSettingsManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)
                
                Text("Upgrade to Premium")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 15) {
                    PremiumFeatureRow(icon: "rectangle.badge.xmark", text: "No ads")
                    PremiumFeatureRow(icon: "drop.fill", text: "No watermark on videos")
                    PremiumFeatureRow(icon: "scalemass", text: "Weight & body fat tracking")
                    PremiumFeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Advanced analytics")
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(15)
                .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 15) {
                    Text("$4.99 / month")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Button(action: {
                        // TODO: Implement in-app purchase
                        userSettings.settings.isPremium = true
                        dismiss()
                    }) {
                        Text("Subscribe Now")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(15)
                    }
                    .padding(.horizontal)
                    
                    Button("Restore Purchase") {
                        // TODO: Implement restore purchase
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PremiumFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.yellow)
                .frame(width: 30)
            Text(text)
                .font(.headline)
            Spacer()
        }
    }
}

struct ExportView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Export your photos to share or backup")
                .multilineTextAlignment(.center)
                .padding()
            
            Button(action: {
                // TODO: Implement export functionality
            }) {
                Label("Export All Photos", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("Export Photos")
        .navigationBarTitleDisplayMode(.inline)
    }
}


struct PasscodeSettingsView: View {
    @State private var currentPasscode = ""
    @State private var newPasscode = ""
    @State private var confirmPasscode = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userSettings = UserSettingsManager()
    
    var body: some View {
        Form {
            if userSettings.settings.appPasscode != nil {
                Section(header: Text("Current Passcode")) {
                    SecureField("Enter current passcode", text: $currentPasscode)
                        .keyboardType(.numberPad)
                }
            }
            
            Section(header: Text("New Passcode")) {
                SecureField("Enter new passcode", text: $newPasscode)
                    .keyboardType(.numberPad)
                
                SecureField("Confirm new passcode", text: $confirmPasscode)
                    .keyboardType(.numberPad)
            }
            
            Section {
                Text("Passcode must be at least 4 digits")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Change Passcode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    savePasscode()
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func savePasscode() {
        // Validate current passcode if exists
        if let existingPasscode = userSettings.settings.appPasscode,
           currentPasscode != existingPasscode {
            errorMessage = "Current passcode is incorrect"
            showingError = true
            return
        }
        
        // Validate new passcode
        guard newPasscode.count >= 4 else {
            errorMessage = "Passcode must be at least 4 digits"
            showingError = true
            return
        }
        
        guard newPasscode == confirmPasscode else {
            errorMessage = "Passcodes do not match"
            showingError = true
            return
        }
        
        userSettings.settings.appPasscode = newPasscode
        dismiss()
    }
}