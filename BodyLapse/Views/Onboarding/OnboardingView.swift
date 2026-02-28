import SwiftUI
import LocalAuthentication
import StoreKit

struct OnboardingView: View {
    @EnvironmentObject var userSettings: UserSettingsManager
    @State private var currentStep = 1
    
    // アプリロック
    @State private var showingAppLockSetup = false
    @State private var selectedLockMethod = UserSettings.AppLockMethod.biometric
    @State private var passcode = ""
    @State private var confirmPasscode = ""
    @State private var showingPasscodeError = false
    @State private var passcodeErrorMessage = ""
    
    // プレミアム
    @State private var showingPremiumView = false
    @StateObject private var premiumViewModel = PremiumViewModel()
    
    // 権限
    @State private var notificationsEnabled = false
    @State private var appLockEnabled = false
    
    // 写真撮影をスキップ
    @State private var didCapturePhoto = false
    
    var body: some View {
        NavigationView {
            VStack {
                // 進捗インジケーター
                progressIndicator
                
                // メインコンテンツ
                TabView(selection: $currentStep) {
                    welcomeStep
                        .tag(1)
                    
                    photoStep
                        .tag(2)
                    
                    personalizationStep
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentStep)
                
                // ナビゲーションボタン
                navigationButtons
            }
            .navigationBarHidden(currentStep == 2 && !didCapturePhoto) // Hide nav bar during camera
        }
        .interactiveDismissDisabled()
        .sheet(isPresented: $showingPremiumView) {
            PremiumView()
        }
        .sheet(isPresented: $showingAppLockSetup, onDismiss: {
            // パスコードが空の場合、ユーザーがキャンセル - アプリロックをオフ
            if passcode.isEmpty {
                appLockEnabled = false
            }
        }) {
            PasscodeSetupView(
                passcode: $passcode,
                confirmPasscode: $confirmPasscode,
                onComplete: {
                    saveAppLockSettings(enableLock: true)
                    appLockEnabled = true
                    // オンボーディング中に認証済みとしてマークし、認証画面の表示を防止
                    if AuthenticationService.shared.isAuthenticationEnabled {
                        AuthenticationService.shared.isAuthenticated = true
                    }
                }
            )
        }
        .alert("common.error".localized, isPresented: $showingPasscodeError) {
            Button("common.ok".localized) { }
        } message: {
            Text(passcodeErrorMessage)
        }
    }
    
    // MARK: - 進捗インジケーター
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .padding()
    }
    
    // MARK: - ステップ1: ようこそ
    private var welcomeStep: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // アプリアイコン
            Image(systemName: "figure.arms.open")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
                .padding(.bottom, 10)
            
            // タイトル
            Text("onboarding.main_title".localized)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .lineSpacing(8)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            // バリュープロポジション
            VStack(alignment: .leading, spacing: 20) {
                ValuePropositionRow(
                    icon: "camera.fill",
                    text: "onboarding.feature.daily_photo".localized
                )
                
                ValuePropositionRow(
                    icon: "video.fill",
                    text: "onboarding.feature.timelapse".localized
                )
                
                ValuePropositionRow(
                    icon: "eye.slash.fill",
                    text: "onboarding.feature.privacy".localized
                )
            }
            .padding(.horizontal, 40)
            
            // プライバシー詳細
            Text("onboarding.privacy_detail".localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            Spacer()
        }
        .padding()
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    // MARK: - Step 2: Photo Capture
    private var photoStep: some View {
        Group {
            if !didCapturePhoto {
                BaselinePhotoCaptureViewWithSkip { photo in
                    didCapturePhoto = true
                } onSkip: {
                    didCapturePhoto = true
                }
            } else {
                // Show success state with options to retake or continue
                VStack(spacing: 30) {
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    Text("onboarding.ready".localized)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("onboarding.photo_saved".localized)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(spacing: 15) {
                        Button(action: {
                            withAnimation {
                                currentStep = 3
                            }
                        }) {
                            Text("common.next".localized)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            didCapturePhoto = false
                        }) {
                            Text("onboarding.retake_photo".localized)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.secondary.opacity(0.2))
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Step 3: Personalization
    private var personalizationStep: some View {
        ScrollView {
            VStack(spacing: 25) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.accentColor)
                    
                    Text("onboarding.customize_title".localized)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .padding(.top, 30)
                .padding(.bottom, 20)
                
                // Settings toggles
                VStack(spacing: 20) {
                    // Notifications
                    SettingToggleRow(
                        icon: "bell.fill",
                        title: "onboarding.reminder_title".localized,
                        subtitle: "onboarding.reminder_subtitle".localized,
                        isOn: $notificationsEnabled,
                        action: {
                            if notificationsEnabled {
                                requestNotificationPermission()
                            }
                        }
                    )
                    
                    // App Lock
                    SettingToggleRow(
                        icon: "lock.shield",
                        title: "onboarding.privacy_lock_title".localized,
                        subtitle: "onboarding.privacy_lock_subtitle".localized,
                        isOn: $appLockEnabled,
                        action: {
                            if appLockEnabled && !showingAppLockSetup {
                                checkBiometricAvailability()
                            }
                        }
                    )
                }
                .padding(.horizontal)
                
                // プレミアム section
                VStack(spacing: 15) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("onboarding.premium_features_title".localized)
                            .font(.headline)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach([
                            "onboarding.premium.noads.description".localized,
                            "onboarding.premium.all_features_free".localized
                        ], id: \.self) { feature in
                            OnboardingPremiumFeatureRow(text: feature)
                        }
                    }
                    
                    Button(action: {
                        showingPremiumView = true
                    }) {
                        Text("onboarding.learn_more".localized)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(15)
                .padding(.horizontal)
                .padding(.top, 10)
                
                Spacer(minLength: 100)
            }
        }
    }
    
    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        HStack {
            // Back button (on step 2 and 3)
            if currentStep > 1 {
                Button(action: {
                    withAnimation {
                        currentStep -= 1
                    }
                }) {
                    Text("common.back".localized)
                        .foregroundColor(.accentColor)
                        .fontWeight(.medium)
                }
                .padding()
            }
            
            Spacer()
            
            // Next/Complete button
            if currentStep == 1 {
                Button(action: {
                    withAnimation {
                        currentStep = 2
                    }
                }) {
                    Text("onboarding.start_now".localized)
                        .frame(minWidth: 120)
                        .padding(.horizontal, 25)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .fontWeight(.semibold)
                }
                .padding()
            } else if currentStep == 2 && !didCapturePhoto {
                // Hide navigation buttons during camera capture
                EmptyView()
            } else if currentStep == 3 {
                Button(action: {
                    completeOnboarding()
                }) {
                    Text("onboarding.complete".localized)
                        .frame(minWidth: 120)
                        .padding(.horizontal, 25)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .fontWeight(.semibold)
                }
                .padding()
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - ヘルパーメソッド
    
    private var biometricIcon: String {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                return "faceid"
            case .touchID:
                return "touchid"
            default:
                return "lock.shield"
            }
        }
        return "lock.shield"
    }
    
    private var biometricLocalizedName: String {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                return "onboarding.enable_faceid".localized
            case .touchID:
                return "onboarding.enable_touchid".localized
            default:
                return "onboarding.enable_biometric".localized
            }
        }
        return "onboarding.enable_biometric".localized
    }
    
    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            // Request authentication to ensure user grants permission
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "onboarding.enable_biometric".localized) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        selectedLockMethod = .biometric
                        showingAppLockSetup = true
                    } else {
                        if let error = authError as NSError? {
                            if error.code == LAError.userCancel.rawValue {
                                appLockEnabled = false
                                return
                            }
                        }
                        passcodeErrorMessage = authError?.localizedDescription ?? "onboarding.enable_biometric".localized
                        showingPasscodeError = true
                        appLockEnabled = false
                    }
                }
            }
        } else {
            // Biometric not available, show passcode setup
            selectedLockMethod = .passcode
            showingAppLockSetup = true
        }
    }
    
    private func saveAppLockSettings(enableLock: Bool) {
        userSettings.settings.isAppLockEnabled = enableLock
        
        if enableLock {
            userSettings.settings.appLockMethod = selectedLockMethod
            if !passcode.isEmpty {
                // Use AuthenticationService to securely store password in Keychain
                if AuthenticationService.shared.setPassword(passcode) {
                    AuthenticationService.shared.isAuthenticationEnabled = true
                    if selectedLockMethod == .biometric {
                        AuthenticationService.shared.isBiometricEnabled = true
                    }
                } else {
                    // Failed to save password
                    passcodeErrorMessage = "Failed to save PIN"
                    showingPasscodeError = true
                    return
                }
            }
        } else {
            // Disable authentication
            AuthenticationService.shared.isAuthenticationEnabled = false
            AuthenticationService.shared.isBiometricEnabled = false
            AuthenticationService.shared.removePassword()
        }
        
        // Save to UserDefaults but don't complete onboarding yet
        if let encoded = try? JSONEncoder().encode(userSettings.settings) {
            UserDefaults.standard.set(encoded, forKey: "BodyLapseUserSettings")
            UserDefaults.standard.synchronize()
        }
    }
    
    private func requestNotificationPermission() {
        NotificationService.shared.requestNotificationPermission { authorized in
            if authorized {
                // Set up daily photo check after permission is granted
                NotificationService.shared.setupDailyPhotoCheck()
            } else {
                // If denied, turn off the toggle
                notificationsEnabled = false
            }
        }
    }
    
    private func completeOnboarding() {
        // Save final settings
        if notificationsEnabled {
            NotificationService.shared.setupDailyPhotoCheck()
        }
        
        // If authentication was enabled during onboarding, mark as authenticated to avoid showing auth screen
        if AuthenticationService.shared.isAuthenticationEnabled {
            AuthenticationService.shared.isAuthenticated = true
        }
        
        // Mark onboarding as complete
        userSettings.settings.hasCompletedOnboarding = true
        
        // Force save to UserDefaults
        if let encoded = try? JSONEncoder().encode(userSettings.settings) {
            UserDefaults.standard.set(encoded, forKey: "BodyLapseUserSettings")
            UserDefaults.standard.synchronize()
        }
    }
}

// MARK: - Supporting Views

struct ValuePropositionRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            Text(text)
                .font(.body)
                .fontWeight(.medium)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

struct SettingToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .onChange(of: isOn) { _, _ in
                    action()
                }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 15)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
}

struct OnboardingPremiumFeatureRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•")
                .font(.body)
                .foregroundColor(.secondary)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

// MARK: - Modified Baseline Photo Capture View with Skip

struct BaselinePhotoCaptureViewWithSkip: View {
    let onPhotoCapture: (Photo) -> Void
    let onSkip: () -> Void
    @State private var cameraController: SimpleCameraViewController?
    @State private var isProcessing = false
    @State private var capturedImage: UIImage?
    @State private var detectedContour: [CGPoint]?
    @State private var showingContourConfirmation = false
    @State private var contourError: String?
    @State private var shouldShowCamera = true
    
    // Timer states
    @State private var timerDuration: Int = 0 // 0 = off, 3, 5, 10 seconds
    @State private var countdownValue: Int = 0
    @State private var isCountingDown = false
    
    init(onPhotoCapture: @escaping (Photo) -> Void, onSkip: @escaping () -> Void) {
        self.onPhotoCapture = onPhotoCapture
        self.onSkip = onSkip
        // Initialize photo storage service
        PhotoStorageService.shared.initialize()
    }
    
    var body: some View {
        ZStack {
            if shouldShowCamera && !showingContourConfirmation {
                SimpleCameraView { image in
                    handlePhotoCapture(image)
                } onReady: { controller in
                    cameraController = controller
                    // Setup timer callbacks
                    controller.timerDuration = timerDuration
                    controller.onCountdownUpdate = { value in
                        countdownValue = value
                        isCountingDown = value > 0
                    }
                    controller.onCountdownComplete = {
                        isCountingDown = false
                    }
                }
                .edgesIgnoringSafeArea(.all)
            } else if let image = capturedImage, let contour = detectedContour {
                // Show contour confirmation view
                ContourConfirmationView(
                    image: image,
                    contour: contour,
                    onConfirm: {
                        saveGuidelineAndPhoto(image: image, contour: contour)
                    },
                    onRetry: {
                        resetForRetake()
                    }
                )
            }
            
            if shouldShowCamera && !showingContourConfirmation {
                VStack {
                    // Top section with timer and camera switch
                    HStack {
                        // Timer button (matching CameraView layout)
                        Menu {
                            Button(action: { 
                                timerDuration = 0
                                cameraController?.timerDuration = 0
                            }) {
                                Label("timer.off".localized, systemImage: timerDuration == 0 ? "checkmark" : "")
                            }
                            Button(action: { 
                                timerDuration = 3
                                cameraController?.timerDuration = 3
                            }) {
                                Label("timer.3s".localized, systemImage: timerDuration == 3 ? "checkmark" : "")
                            }
                            Button(action: { 
                                timerDuration = 5
                                cameraController?.timerDuration = 5
                            }) {
                                Label("timer.5s".localized, systemImage: timerDuration == 5 ? "checkmark" : "")
                            }
                            Button(action: { 
                                timerDuration = 10
                                cameraController?.timerDuration = 10
                            }) {
                                Label("timer.10s".localized, systemImage: timerDuration == 10 ? "checkmark" : "")
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                    .font(.title3)
                                if timerDuration > 0 {
                                    Text("\(timerDuration)s")
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(width: 60, height: 50)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 25))
                        }
                        .disabled(cameraController == nil)
                        .opacity(cameraController == nil ? 0.5 : 1.0)
                        .padding(.leading, 20)
                        
                        Spacer()
                        
                        // カメラ切り替え button (matching CameraView size)
                        Button(action: {
                            guard let controller = cameraController else { return }
                            controller.switchCamera()
                        }) {
                            Image(systemName: "camera.rotate")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .disabled(cameraController == nil)
                        .opacity(cameraController == nil ? 0.5 : 1.0)
                        .padding(.trailing, 20)
                    }
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    // カウントダウン表示
                    if isCountingDown {
                        Text("\(countdownValue)")
                            .font(.system(size: 120, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                            .transition(.scale.combined(with: .opacity))
                            .animation(.easeInOut(duration: 0.3), value: countdownValue)
                    }
                    
                    Spacer()
                    
                    // Bottom section with instructions and buttons
                    VStack(spacing: 20) {
                        VStack(spacing: 10) {
                            Text("onboarding.photo_title".localized)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .shadow(radius: 2)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            VStack(spacing: 4) {
                                Text("onboarding.hint_label".localized)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                Text("onboarding.hint_text".localized)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            Text("onboarding.reset_note".localized)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.top, 5)
                        }
                        .padding(.horizontal, 30)
                        
                        // Cancel button during countdown
                        if isCountingDown {
                            Button(action: {
                                cameraController?.cancelCountdown()
                                isCountingDown = false
                                countdownValue = 0
                            }) {
                                Text("common.cancel".localized)
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.red.opacity(0.8))
                                    .cornerRadius(20)
                            }
                        }
                        
                        // 撮影ボタン
                        Button(action: {
                            guard let controller = cameraController, !isProcessing else { return }
                            controller.capturePhoto()
                        }) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                        .frame(width: 80, height: 80)
                                )
                        }
                        .disabled(isProcessing || cameraController == nil || isCountingDown)
                        .opacity(isProcessing || cameraController == nil || isCountingDown ? 0.5 : 1.0)
                        .padding(.bottom, 20)
                    }
                    
                    // Skip button at bottom right
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            onSkip()
                        }) {
                            Text("common.skip".localized)
                                .font(.body)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(20)
                        }
                        .padding(.trailing, 30)
                        .padding(.bottom, 30)
                    }
                }
            }
            
            if isProcessing {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
    }
    
    private func handlePhotoCapture(_ image: UIImage) {
        isProcessing = true
        capturedImage = image
        
        // Detect body contour
        BodyContourService.shared.detectBodyContour(from: image) { result in
            DispatchQueue.main.async { [self] in
                
                switch result {
                case .success(let contour):
                    self.detectedContour = contour
                    self.isProcessing = false
                    self.showingContourConfirmation = true
                    
                case .failure(let error):
                    self.contourError = error.localizedDescription
                    self.isProcessing = false
                    // Still show confirmation without contour to let user proceed
                    self.detectedContour = []
                    self.showingContourConfirmation = true
                }
            }
        }
    }
    
    private func resetForRetake() {
        // Reset all state immediately
        showingContourConfirmation = false
        capturedImage = nil
        detectedContour = nil
        contourError = nil
        isProcessing = false
        cameraController = nil
        
        // Reset timer states
        isCountingDown = false
        countdownValue = 0
        
        // Toggle camera visibility to force complete re-initialization
        shouldShowCamera = false
        
        // Re-enable camera after next run loop to ensure clean state
        DispatchQueue.main.async {
            self.shouldShowCamera = true
        }
    }
    
    private func saveGuidelineAndPhoto(image: UIImage, contour: [CGPoint]) {
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Save the guideline if we have a valid contour
                if !contour.isEmpty {
                    // Check if front camera and mirror the contour points if needed
                    let isFrontCamera = self.cameraController?.currentPosition == .front
                    var finalContour = contour
                    
                    if isFrontCamera {
                        // Mirror the X coordinates of all points
                        finalContour = contour.map { point in
                            CGPoint(x: image.size.width - point.x, y: point.y)
                        }
                    }
                    
                    let guideline = BodyGuideline(points: finalContour, imageSize: image.size, isFrontCamera: isFrontCamera)
                    GuidelineStorageService.shared.saveGuideline(guideline)
                }
                
                // Save baseline photo without face blur
                let photo = try PhotoStorageService.shared.savePhoto(
                    image,
                    isFaceBlurred: false
                )
                
                DispatchQueue.main.async { [self] in
                    self.isProcessing = false
                    self.onPhotoCapture(photo)
                }
            } catch {
                DispatchQueue.main.async { [self] in
                    self.isProcessing = false
                    // Even if save fails, continue
                    self.onSkip()
                }
            }
        }
    }
}

// MARK: - Keep existing PasscodeSetupView
struct PasscodeSetupView: View {
    @Binding var passcode: String
    @Binding var confirmPasscode: String
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("onboarding.create_passcode".localized)) {
                    SecureField("onboarding.enter_passcode".localized, text: $passcode)
                        .keyboardType(.numberPad)
                        .onChange(of: passcode) { _, newValue in
                            // Limit to 4 digits
                            if newValue.count > 4 {
                                passcode = String(newValue.prefix(4))
                            }
                            // Only allow numbers
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered != newValue {
                                passcode = filtered
                            }
                        }
                    
                    SecureField("onboarding.confirm_passcode".localized, text: $confirmPasscode)
                        .keyboardType(.numberPad)
                        .onChange(of: confirmPasscode) { _, newValue in
                            // Limit to 4 digits
                            if newValue.count > 4 {
                                confirmPasscode = String(newValue.prefix(4))
                            }
                            // Only allow numbers
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered != newValue {
                                confirmPasscode = filtered
                            }
                        }
                }
            }
            .navigationTitle("onboarding.setup_passcode".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        // Reset the passcode fields
                        passcode = ""
                        confirmPasscode = ""
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        validateAndSave()
                    }
                    .disabled(passcode.count != 4 || confirmPasscode.count != 4)
                }
            }
            .alert("common.error".localized, isPresented: $showingError) {
                Button("common.ok".localized) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func validateAndSave() {
        guard passcode == confirmPasscode else {
            errorMessage = "onboarding.passcode_mismatch".localized
            showingError = true
            return
        }
        
        onComplete()
        dismiss()
    }
}

#Preview {
    OnboardingView()
        .environmentObject(UserSettingsManager.shared)
}
