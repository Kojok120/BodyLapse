import SwiftUI

struct SettingsView: View {
    @StateObject private var userSettings = UserSettingsManager.shared
    @StateObject private var subscriptionManager = SubscriptionManagerService.shared
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var languageManager = LanguageManager.shared
    @State private var showingAbout = false
    @State private var showingPremiumUpgrade = false
    @State private var showingPasswordSetup = false
    @State private var showingChangePassword = false
    @State private var showingNotificationPermissionAlert = false
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
                    if subscriptionManager.isPremium {
                        NavigationLink(destination: CategoryManagementView()) {
                            Label("settings.category_management".localized, systemImage: "folder.badge.gearshape")
                        }
                    } else {
                        Button(action: { showingPremiumUpgrade = true }) {
                            HStack {
                                Label("settings.category_management".localized, systemImage: "folder.badge.gearshape")
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    
                    Toggle("settings.show_guidelines".localized, isOn: $userSettings.settings.showBodyGuidelines)
                    
                    // Only show guideline button for free users
                    if !subscriptionManager.isPremium {
                        Button(action: {
                            if GuidelineStorageService.shared.hasGuideline() {
                                showingResetGuidelineConfirmation = true
                            } else {
                                // If no guideline exists, directly show the guideline setup
                                showingResetGuideline = true
                            }
                        }) {
                            if GuidelineStorageService.shared.hasGuideline() {
                                Label("settings.reset_guideline".localized, systemImage: "arrow.uturn.backward")
                                    .foregroundColor(.red)
                            } else {
                                Label("settings.set_guideline".localized, systemImage: "person.fill.viewfinder")
                                    .foregroundColor(.blue)
                            }
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
                
                Section("settings.security".localized) {
                    Toggle("settings.app_lock".localized, isOn: .init(
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
                            Label("settings.change_pin".localized, systemImage: "number.square")
                        }
                    }
                }
                
                Section("settings.reminders".localized) {
                    Toggle("settings.daily_reminder".localized, isOn: $userSettings.settings.reminderEnabled)
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
                        DatePicker("settings.reminder_time".localized,
                                   selection: $userSettings.settings.reminderTime,
                                   displayedComponents: .hourAndMinute)
                    }
                }
                
                Section("settings.premium_features".localized) {
                    if subscriptionManager.isPremium {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                            Text("settings.premium_active".localized)
                                .foregroundColor(.secondary)
                        }
                        
                        // Manage Subscription Button
                        Button(action: {
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "creditcard")
                                    .foregroundColor(.blue)
                                Text("settings.manage_subscription".localized)
                                Spacer()
                                Image(systemName: "arrow.up.forward")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                        
                        // HealthKit Integration
                        Toggle(isOn: $healthKitEnabled) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.red)
                                VStack(alignment: .leading) {
                                    Text("settings.sync_health".localized)
                                    Text("settings.auto_import".localized)
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
                                    Text("settings.sync_now".localized)
                                }
                            }
                            .disabled(healthKitSyncInProgress)
                        }
                    } else {
                        Button(action: { showingPremiumUpgrade = true }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("settings.upgrade_premium".localized)
                                        .font(.headline)
                                    Text("settings.premium_description".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if let product = subscriptionManager.products.first {
                                    Text(product.displayPrice)
                                        .fontWeight(.semibold)
                                } else {
                                    Text("settings.premium_price".localized)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("settings.data".localized)) {
                    NavigationLink(destination: ImportExportView()) {
                        Label("データのインポート/エクスポート", systemImage: "arrow.up.arrow.down.square")
                    }
                    
                    // Data clearing feature - to be implemented in future version
                    /*
                    Button(role: .destructive) {
                        // Implement data clearing logic
                    } label: {
                        Label("settings.clear_all_data".localized, systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    */
                }
                
                Section("settings.about".localized) {
                    Button(action: { showingAbout = true }) {
                        HStack {
                            Text("settings.about_bodylapse".localized)
                            Spacer()
                            Text("settings.version".localized)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://kojok120.github.io/bodylapse-legal/privacy_policy.html")!) {
                        Label("settings.privacy_policy".localized, systemImage: "hand.raised")
                    }
                    
                    Link(destination: URL(string: "https://kojok120.github.io/bodylapse-legal/terms_of_service.html")!) {
                        Label("settings.terms_service".localized, systemImage: "doc.text")
                    }
                }
                
                #if DEBUG
                Section(header: Text("Debug Options")) {
                    Toggle("Premium Mode", isOn: Binding(
                        get: { subscriptionManager.isPremium },
                        set: { _ in subscriptionManager.toggleDebugPremium() }
                    ))
                    
                    HStack {
                        Text("Subscription Status")
                        Spacer()
                        Text(subscriptionManager.subscriptionStatusDescription)
                            .foregroundColor(.secondary)
                    }
                    
                    if subscriptionManager.isPremium {
                        HStack {
                            Text("Expiration Date")
                            Spacer()
                            if let date = subscriptionManager.expirationDate {
                                Text(date, style: .date)
                                    .foregroundColor(.secondary)
                            }
                        }
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
            .alert("settings.notification_required".localized, isPresented: $showingNotificationPermissionAlert) {
                Button("settings.open_settings".localized) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("common.cancel".localized, role: .cancel) { }
            } message: {
                Text("settings.notification_message".localized)
            }
            .alert("settings.health_required".localized, isPresented: $showingHealthKitPermission) {
                Button("common.ok".localized) { }
            } message: {
                Text("settings.health_message".localized)
            }
            .alert("settings.reset_guideline".localized, isPresented: $showingResetGuidelineConfirmation) {
                Button("common.cancel".localized, role: .cancel) { }
                Button("settings.reset".localized, role: .destructive) {
                    showingResetGuideline = true
                }
            } message: {
                Text("settings.reset_guideline_confirm".localized)
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
                
                Text("about.bodylapse".localized)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("about.tagline".localized)
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 15) {
                    FeatureRow(icon: "camera.fill", text: "about.feature1".localized)
                    FeatureRow(icon: "calendar", text: "about.feature2".localized)
                    FeatureRow(icon: "video.fill", text: "about.feature3".localized)
                    FeatureRow(icon: "lock.fill", text: "about.feature4".localized)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(15)
                .padding(.horizontal)
                
                Spacer()
                
                Text("about.made_with_love".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("settings.about".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
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
                
                Text("settings.upgrade_premium".localized)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 15) {
                    PremiumFeatureRow(icon: "rectangle.badge.xmark", text: "premium.feature.no_ads".localized)
                    PremiumFeatureRow(icon: "drop.fill", text: "premium.feature.no_watermark".localized)
                    PremiumFeatureRow(icon: "scalemass", text: "premium.feature.tracking".localized)
                    PremiumFeatureRow(icon: "chart.line.uptrend.xyaxis", text: "premium.feature.reminders".localized)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(15)
                .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 15) {
                    Text("settings.premium_price".localized)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Button(action: {
                        // TODO: Implement in-app purchase
                        // Premium status is managed by SubscriptionManagerService
                        dismiss()
                    }) {
                        Text("premium.subscribe".localized)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(15)
                    }
                    .padding(.horizontal)
                    
                    // Restore purchase feature - handled by StoreKit automatically
                    /*
                    Button("premium.restore".localized) {
                        // Implement restore purchase
                    }
                    */
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
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
            Text("export.description".localized)
                .multilineTextAlignment(.center)
                .padding()
            
            // Export feature - to be implemented in future version
            /*
            Button(action: {
                // Implement export functionality
            }) {
                Label("export.all_photos".localized, systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            */
            
            Spacer()
        }
        .navigationTitle("export.title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}


