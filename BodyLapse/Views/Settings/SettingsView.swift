import SwiftUI

struct SettingsView: View {
    @StateObject private var userSettings = UserSettingsManager.shared
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var languageManager = LanguageManager.shared
    @State private var showingAbout = false
    @State private var showingPremiumUpgrade = false
    @State private var showingPasswordSetup = false
    @State private var showingChangePassword = false
    @State private var showingNotificationPermissionAlert = false
    #if DEBUG
    @State private var showingDebugSettings = false
    #endif
    @State private var healthKitEnabled = false
    @State private var showingHealthKitPermission = false
    @State private var healthKitSyncInProgress = false
    @State private var showingResetGuidelineConfirmation = false
    @State private var showingResetGuideline = false
    @State private var showingLanguageChangeAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("settings.photo_settings".localized) {
                    Toggle("settings.show_guidelines".localized, isOn: $userSettings.settings.showBodyGuidelines)
                    
                    if GuidelineStorageService.shared.hasGuideline() {
                        Button(action: {
                            showingResetGuidelineConfirmation = true
                        }) {
                            Label("settings.reset_guideline".localized, systemImage: "arrow.uturn.backward")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Picker("settings.weight_unit".localized, selection: $userSettings.settings.weightUnit) {
                        ForEach(UserSettings.WeightUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    
                    // Language Selection
                    Picker("settings.language".localized, selection: $languageManager.currentLanguage) {
                        ForEach(languageManager.supportedLanguages, id: \.self) { language in
                            Text(languageManager.getLanguageName(for: language))
                                .tag(language)
                        }
                    }
                    .onChange(of: languageManager.currentLanguage) { _, _ in
                        showingLanguageChangeAlert = true
                    }
                }
                
                Section("Security") {
                    Toggle("App Lock", isOn: .init(
                        get: { authService.isAuthenticationEnabled },
                        set: { newValue in
                            if newValue {
                                if !authService.hasPassword {
                                    showingPasswordSetup = true
                                } else {
                                    authService.isAuthenticationEnabled = true
                                }
                            } else {
                                authService.isAuthenticationEnabled = false
                            }
                        }
                    ))
                    
                    if authService.isAuthenticationEnabled {
                        Toggle("\(authService.biometricTypeString)", isOn: .init(
                            get: { authService.isBiometricEnabled },
                            set: { authService.isBiometricEnabled = $0 }
                        ))
                        .disabled(authService.biometricType == .none)
                        
                        Button(action: { showingChangePassword = true }) {
                            Label("Change PIN", systemImage: "number.square")
                        }
                    }
                }
                
                Section("Reminders") {
                    Toggle("Daily Reminder", isOn: $userSettings.settings.reminderEnabled)
                        .onChange(of: userSettings.settings.reminderEnabled) {  _, newValue in
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
                        
                        // HealthKit Integration
                        Toggle(isOn: $healthKitEnabled) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.red)
                                VStack(alignment: .leading) {
                                    Text("Sync with Health")
                                    Text("Auto-import weight & body fat")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .onChange(of: healthKitEnabled) { _, newValue in
                            if newValue {
                                requestHealthKitPermission()
                            } else {
                                userSettings.settings.healthKitEnabled = false
                            }
                        }
                        
                        if healthKitEnabled {
                            Button(action: syncHealthData) {
                                HStack {
                                    if healthKitSyncInProgress {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                    }
                                    Text("Sync Now")
                                }
                            }
                            .disabled(healthKitSyncInProgress)
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
            .navigationTitle("settings.title".localized)
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingPremiumUpgrade) {
                PremiumView()
            }
            .sheet(isPresented: $showingPasswordSetup) {
                PasswordSetupView {
                    authService.isAuthenticationEnabled = true
                }
            }
            .sheet(isPresented: $showingChangePassword) {
                ChangePasswordView()
            }
            #if DEBUG
            .sheet(isPresented: $showingDebugSettings) {
                DebugSettingsView()
            }
            #endif
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
            .alert("Health Access Required", isPresented: $showingHealthKitPermission) {
                Button("OK") { }
            } message: {
                Text("Please grant access to read and write weight and body fat data in the Health app.")
            }
            .alert("Reset Body Guideline", isPresented: $showingResetGuidelineConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    showingResetGuideline = true
                }
            } message: {
                Text("Are you sure you want to reset your body guideline? You will need to take a new photo to set it up again.")
            }
            .fullScreenCover(isPresented: $showingResetGuideline) {
                ResetGuidelineView()
            }
            .alert("common.done".localized, isPresented: $showingLanguageChangeAlert) {
                Button("common.ok".localized) {
                    // Force app refresh
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                        windowScene.windows.first?.rootViewController = UIHostingController(
                            rootView: ContentView()
                                .environmentObject(languageManager)
                        )
                    }
                }
            } message: {
                Text("settings.language_changed".localized)
            }
            .onAppear {
                healthKitEnabled = userSettings.settings.healthKitEnabled
            }
        }
    }
    
    private func requestHealthKitPermission() {
        HealthKitService.shared.requestAuthorization { success, error in
            if success {
                userSettings.settings.healthKitEnabled = true
                healthKitEnabled = true
                // Perform initial sync
                syncHealthData()
            } else {
                healthKitEnabled = false
                if error != nil {
                    showingHealthKitPermission = true
                }
            }
        }
    }
    
    private func syncHealthData() {
        healthKitSyncInProgress = true
        
        HealthKitService.shared.syncHealthDataToApp { success, error in
            healthKitSyncInProgress = false
            
            if success {
                // Reload weight data in the app
                NotificationCenter.default.post(name: Notification.Name("HealthKitDataSynced"), object: nil)
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


