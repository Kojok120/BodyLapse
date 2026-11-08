import SwiftUI

struct SettingsView: View {
    @StateObject private var userSettings = UserSettingsManager.shared
    @StateObject private var subscriptionManager = SubscriptionManagerService.shared
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var appearanceManager = AppearanceManager.shared
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
    @State private var isNotificationEnabled = false
    
    // カテゴリー管理ガイダンス
    
    
    // App Store ID - アプリ公開時に実際のIDに置き換え
    private let appStoreID = "6747956750"
    
    var body: some View {
        NavigationView {
            mainContent
        }
    }
    
    private var mainContent: some View {
        Form {
                Section("settings.photo_settings".localized) {
                    // カテゴリー管理は全ユーザーに利用可能
                    NavigationLink(destination: CategoryManagementView()) {
                        Label("settings.category_management".localized, systemImage: "folder.badge.gearshape")
                    }
                    
                    Toggle("settings.show_guidelines".localized, isOn: $userSettings.settings.showBodyGuidelines)
                    
                    // 顔ぼかし方式選択
                    Picker("settings.face_blur_method".localized, selection: $userSettings.settings.faceBlurMethod) {
                        ForEach(UserSettings.FaceBlurMethod.allCases, id: \.self) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                    
                    // ガイドラインボタンは全ユーザーに利用可能
                    Button(action: {
                        if GuidelineStorageService.shared.hasGuideline() {
                            showingResetGuidelineConfirmation = true
                        } else {
                            // ガイドラインが存在しない場合、直接ガイドライン設定を表示
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
                    
                    // 体重単位 - 全ユーザーに利用可能
                    Picker("settings.weight_unit".localized, selection: $userSettings.settings.weightUnit) {
                        ForEach(UserSettings.WeightUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    
                    // 言語選択
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
                
                Section("settings.appearance".localized) {
                    Picker("settings.appearance_mode".localized, selection: $appearanceManager.currentAppearance) {
                        ForEach(UserSettings.AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }
                
                Section("settings.reminders".localized) {
                    if !isNotificationEnabled {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.blue)
                            Text("settings.daily_reminder".localized)
                            Spacer()
                            Button("common.enable".localized) {
                                requestNotificationPermission()
                            }
                            .foregroundColor(.blue)
                        }
                    } else {
                        // デイリーリマインダー時刻設定
                        Toggle("settings.daily_reminder".localized, isOn: $userSettings.settings.isReminderEnabled)
                            .onChange(of: userSettings.settings.isReminderEnabled) { _, isEnabled in
                                if isEnabled {
                                    NotificationService.shared.scheduleDailyReminder()
                                } else {
                                    NotificationService.shared.cancelDailyReminder()
                                }
                            }

                        if userSettings.settings.isReminderEnabled {
                            DatePicker(
                                "settings.reminder_time".localized,
                                selection: Binding(
                                    get: {
                                        Calendar.current.date(from: DateComponents(
                                            hour: userSettings.settings.reminderHour,
                                            minute: userSettings.settings.reminderMinute
                                        )) ?? Date()
                                    },
                                    set: { newDate in
                                        let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                        userSettings.settings.reminderHour = components.hour ?? 19
                                        userSettings.settings.reminderMinute = components.minute ?? 0
                                        // 新しい時刻でデイリーリマインダーを再スケジュール
                                        NotificationService.shared.scheduleDailyReminder()
                                    }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                        }
                    }
                }
                
                // HealthKit連携 - 全ユーザーに利用可能
                // 見出しは節の 1 回だけにし、切り替えは 1 行にする (「ヘルス連携」「Apple ヘルスケア連携」「ヘルスと同期」の 3 段だった)
                Section("settings.health_integration".localized) {
                    Toggle(isOn: $healthKitEnabled) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("settings.sync_health".localized)
                                Text("settings.auto_import".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "heart.text.square.fill")
                                .foregroundColor(.red)
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
                }
                
                // プレミアム section for ads removal only
                Section("settings.premium_features".localized) {
                    if subscriptionManager.isPremium {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                            Text("settings.premium_active".localized)
                                .foregroundColor(.secondary)
                        }

                        // トライアル / 次回更新までの残り日数を表示（解約前の再検討機会）
                        if let days = subscriptionManager.daysUntilExpiration {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(subscriptionManager.isAboutToExpire ? .orange : .secondary)
                                if subscriptionManager.isInTrialPeriod {
                                    Text("settings.premium.trial_days_left".localized(with: days))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("settings.premium.renews_in".localized(with: days))
                                        .font(.subheadline)
                                        .foregroundColor(subscriptionManager.isAboutToExpire ? .orange : .secondary)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }

                        // サブスクリプション管理ボタン
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
                    } else {
                        Button(action: {
                            showingPremiumUpgrade = true
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("settings.upgrade_premium".localized)
                                        .font(.headline)
                                    Text("settings.no_ads_only".localized) // Update text to mention only ad removal
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                // 広告を消すだけの Standard の値段を出す。並び順任せにせず商品 ID で引き、
                                // 取れないときは固定の値段 (通貨が合わないことがある) を出さない
                                if let product = subscriptionManager.products.first(where: { $0.id == StoreProducts.premiumMonthly }) {
                                    Text(product.displayPrice)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("settings.data".localized)) {
                    NavigationLink(destination: ImportExportView()) {
                        Label("settings.import_export".localized, systemImage: "arrow.up.arrow.down.square")
                    }

                    // クラウドバックアップ（Pro限定）
                    if subscriptionManager.isPro {
                        NavigationLink(destination: CloudBackupView()) {
                            Label("cloud.title".localized, systemImage: "icloud")
                        }
                    } else {
                        Button {
                            showingPremiumUpgrade = true
                        } label: {
                            HStack {
                                Label("cloud.title".localized, systemImage: "icloud")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("premium.pro.title".localized)
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.bodyLapseTurquoise)
                                    .clipShape(Capsule())
                            }
                        }
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
                        }
                    }
                    
                    Link(destination: URL(string: "https://kojok120.github.io/bodylapse-legal/privacy_policy.html")!) {
                        Label("settings.privacy_policy".localized, systemImage: "hand.raised")
                    }

                    // 広告の同意を取った地域 (EEA・英国など) でだけ、同意の内容を変える入口を出す
                    if AdConsentService.shared.isPrivacyOptionsRequired {
                        Button {
                            Task { await AdConsentService.shared.presentPrivacyOptions() }
                        } label: {
                            Label("settings.ad_privacy_options".localized, systemImage: "checkmark.shield")
                        }
                    }
                    
                    Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                        Label("settings.terms_use".localized, systemImage: "doc.text")
                    }
                }
                
                Section {
                    Button(action: {
                        if let url = URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Label("settings.write_review".localized, systemImage: "star.fill")
                            .foregroundColor(.primary)
                    }
                }
                
                #if DEBUG
                Section(header: Text("settings.debug_options".localized)) {
                    Toggle("settings.debug.premium_mode".localized, isOn: Binding(
                        get: { subscriptionManager.tier == .standard },
                        set: { _ in subscriptionManager.toggleDebugPremium() }
                    ))

                    Toggle("settings.debug.pro_mode".localized, isOn: Binding(
                        get: { subscriptionManager.tier == .pro },
                        set: { _ in subscriptionManager.toggleDebugPro() }
                    ))

                    Toggle("settings.debug.past_photos".localized, isOn: $userSettings.settings.debugAllowPastDatePhotos)

                    Button(action: openDebugOnboarding) {
                        Label("settings.debug.launch_onboarding".localized, systemImage: "sparkles")
                            .foregroundColor(.accentColor)
                    }
                    
                    HStack {
                        Text("settings.subscription_status".localized)
                        Spacer()
                        Text(subscriptionManager.subscriptionStatusDescription)
                            .foregroundColor(.secondary)
                    }
                    
                    if subscriptionManager.isPremium {
                        HStack {
                            Text("settings.expiration_date".localized)
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
                ResetGuidelineView(categoryId: PhotoCategory.defaultCategory.id, categoryName: PhotoCategory.defaultCategory.name)
            }
            .alert("common.done".localized, isPresented: $showingLanguageChangeAlert) {
                Button("common.ok".localized) {
                    resetRootToContentView()
                }
            } message: {
                Text("settings.language_changed".localized)
            }
            .onAppear {
                healthKitEnabled = userSettings.settings.healthKitEnabled
                checkNotificationStatus()
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
    
    private func checkNotificationStatus() {
        NotificationService.shared.checkNotificationPermission { authorized in
            isNotificationEnabled = authorized
        }
    }
    
    private func requestNotificationPermission() {
        NotificationService.shared.requestNotificationPermission { authorized in
            if authorized {
                isNotificationEnabled = true
                // Set up daily photo check after permission is granted
                NotificationService.shared.setupDailyPhotoCheck()
            } else {
                // Permission denied - show alert to open settings
                showingNotificationPermissionAlert = true
            }
        }
    }

#if DEBUG
    private func openDebugOnboarding() {
        userSettings.settings.hasCompletedOnboarding = false
        authService.isAuthenticated = false
        resetRootToContentView()
    }
#endif

    /// 画面の階層を作り直す。rootViewController を差し替えると、目隠しやロックの購読を持つ
    /// App の階層ごと失われていたため、App 側の .id を変えて SwiftUI に作り直させる
    private func resetRootToContentView() {
        languageManager.reloadUI()
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var appVersionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    private var appBuildString: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

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
                
                Button(action: {
                    if let url = URL(string: "https://kojok120.github.io/bodylapse-legal/contact.html") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.accentColor)
                        Text("about.contact".localized)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Text("about.made_with_love".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("about.version".localized(with: appVersionString, appBuildString))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("about.version".localized(with: appVersionString, appBuildString))
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
