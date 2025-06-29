import SwiftUI
import LocalAuthentication

struct OnboardingView: View {
    @EnvironmentObject var userSettings: UserSettingsManager
    @State private var currentStep = 1
    @State private var isInOnboardingPhase = false
    
    // App lock
    @State private var showingAppLockSetup = false
    @State private var selectedLockMethod = UserSettings.AppLockMethod.biometric
    @State private var passcode = ""
    @State private var confirmPasscode = ""
    @State private var showingPasscodeError = false
    @State private var passcodeErrorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if !isInOnboardingPhase {
                    // Explanation phase
                    VStack {
                        explanationProgressIndicator
                        
                        TabView(selection: $currentStep) {
                            featureStep1
                                .tag(1)
                            
                            featureStep2
                                .tag(2)
                            
                            featureStep3
                                .tag(3)
                            
                            featureStep4
                                .tag(4)
                            
                            featureStep5
                                .tag(5)
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .animation(.easeInOut, value: currentStep)
                        
                        explanationNavigationButtons
                    }
                } else {
                    // Onboarding phase
                    VStack {
                        onboardingProgressIndicator
                        
                        TabView(selection: $currentStep) {
                            letsGetStartedStep
                                .tag(1)
                            
                            baselinePhotoStep
                                .tag(2)
                            
                            appLockStep
                                .tag(3)
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .animation(.easeInOut, value: currentStep)
                        
                        onboardingNavigationButtons
                    }
                }
            }
            .navigationTitle(isInOnboardingPhase ? "onboarding.setup_account".localized : "onboarding.welcome".localized)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(isInOnboardingPhase && currentStep == 2) // Hide for camera step
        }
        .interactiveDismissDisabled()
    }
    
    private var explanationProgressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .padding()
    }
    
    private var onboardingProgressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .padding()
    }
    
    // Feature explanation steps
    private var featureStep1: some View {
        featureExplanationView(
            icon: "camera.fill",
            title: "onboarding.daily_photos.title".localized,
            description: "onboarding.daily_photos.subtitle".localized,
            subDescription: "onboarding.daily_photos.description".localized
        )
    }
    
    private var featureStep2: some View {
        featureExplanationView(
            icon: "video.fill",
            title: "onboarding.timelapse.title".localized,
            description: "onboarding.timelapse.subtitle".localized,
            subDescription: "onboarding.timelapse.description".localized
        )
    }
    
    private var featureStep3: some View {
        featureExplanationView(
            icon: "eye.slash.fill",
            title: "onboarding.privacy.title".localized,
            description: "onboarding.privacy.subtitle".localized,
            subDescription: "onboarding.privacy.description".localized
        )
    }
    
    private var featureStep4: some View {
        featureExplanationView(
            icon: "photo.on.rectangle.angled",
            title: "onboarding.comparison.title".localized,
            description: "onboarding.comparison.subtitle".localized,
            subDescription: "onboarding.comparison.description".localized
        )
    }
    
    private var featureStep5: some View {
        premiumFeaturesView
    }
    
    private var letsGetStartedStep: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "figure.arms.open")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
                .padding(.bottom, 20)
            
            Text("onboarding.start.title".localized)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("onboarding.start.subtitle".localized)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            Spacer()
        }
        .padding()
    }
    
    private func featureExplanationView(icon: String, title: String, description: String, subDescription: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
                .padding(.bottom, 20)
            
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(description)
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 30)
            
            Text(subDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 40)
                .padding(.top, 10)
            
            Spacer()
            Spacer()
        }
        .padding()
    }
    
    private var premiumFeaturesView: some View {
        ScrollView {
            VStack(spacing: 30) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)
                    .padding(.bottom, 10)
                    .padding(.top, 40)
                
                Text("onboarding.premium.title".localized)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("onboarding.premium.subtitle".localized)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 30)
                
                VStack(spacing: 20) {
                    premiumFeatureItem(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "onboarding.premium.metrics.title".localized,
                        description: "onboarding.premium.metrics.description".localized
                    )
                    
                    premiumFeatureItem(
                        icon: "video.badge.checkmark",
                        title: "onboarding.premium.nowatermark.title".localized,
                        description: "onboarding.premium.nowatermark.description".localized
                    )
                    
                    premiumFeatureItem(
                        icon: "eye.slash",
                        title: "onboarding.premium.noads.title".localized,
                        description: "onboarding.premium.noads.description".localized
                    )
                    
                    premiumFeatureItem(
                        icon: "calendar.badge.plus",
                        title: "onboarding.premium.daterange.title".localized,
                        description: "onboarding.premium.daterange.description".localized
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                VStack(spacing: 10) {
                    Text("onboarding.premium.price".localized)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("onboarding.premium.price.detail".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
    }
    
    private func premiumFeatureItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.horizontal, 10)
    }
    
    private var baselinePhotoStep: some View {
        BaselinePhotoCaptureView { photo in
            // Photo captured, move to next step
            currentStep = 3
        }
    }
    
    private var appLockStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
                .padding(.bottom, 20)
            
            Text("onboarding.security.title".localized)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("onboarding.security.subtitle".localized)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                Button(action: {
                    checkBiometricAvailability()
                }) {
                    HStack {
                        Image(systemName: biometricIcon)
                        Text(biometricLocalizedName)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                Button(action: {
                    selectedLockMethod = .passcode
                    showingAppLockSetup = true
                }) {
                    HStack {
                        Image(systemName: "number")
                        Text("onboarding.setup_passcode".localized)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingAppLockSetup) {
            PasscodeSetupView(
                passcode: $passcode,
                confirmPasscode: $confirmPasscode,
                onComplete: {
                    saveSettings(enableLock: true)
                }
            )
        }
        .alert("common.error".localized, isPresented: $showingPasscodeError) {
            Button("common.ok".localized) { }
        } message: {
            Text(passcodeErrorMessage)
        }
    }
    
    private var explanationNavigationButtons: some View {
        HStack {
            if currentStep > 1 {
                Button(action: {
                    hideKeyboard()
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
            
            if currentStep < 5 {
                Button(action: {
                    hideKeyboard()
                    withAnimation {
                        currentStep += 1
                    }
                }) {
                    Text("common.next".localized)
                        .frame(minWidth: 80)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .fontWeight(.medium)
                }
                .padding()
            } else {
                Button(action: {
                    hideKeyboard()
                    withAnimation {
                        isInOnboardingPhase = true
                        currentStep = 1
                    }
                }) {
                    Text("common.continue".localized)
                        .frame(minWidth: 80)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .fontWeight(.medium)
                }
                .padding()
            }
        }
        .padding(.horizontal)
    }
    
    private var onboardingNavigationButtons: some View {
        HStack {
            if currentStep > 1 && currentStep != 2 {
                Button(action: {
                    hideKeyboard()
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
            
            if currentStep == 1 {
                Button(action: {
                    hideKeyboard()
                    withAnimation {
                        currentStep = 2
                    }
                }) {
                    Text("onboarding.start".localized)
                        .frame(minWidth: 80)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .fontWeight(.medium)
                }
                .padding()
            } else if currentStep == 3 {
                Button(action: {
                    hideKeyboard()
                    saveSettings(enableLock: false)
                }) {
                    Text("common.skip".localized)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                }
                .padding()
                
                Button(action: {
                    hideKeyboard()
                    saveSettings(enableLock: false)
                }) {
                    Text("common.finish".localized)
                        .frame(minWidth: 80)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .fontWeight(.medium)
                }
                .padding()
            }
        }
        .padding(.horizontal)
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
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
    
    private var biometricName: String {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                return "Face ID"
            case .touchID:
                return "Touch ID"
            default:
                return "Biometric Authentication"
            }
        }
        return "Biometric Authentication"
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
        
        print("Checking biometric availability...")
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            print("Biometric available, type: \(context.biometryType.rawValue)")
            
            // Request authentication to ensure user grants permission
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "onboarding.enable_biometric".localized) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        print("Biometric authentication successful")
                        selectedLockMethod = .biometric
                        saveSettings(enableLock: true)
                    } else {
                        print("Biometric authentication failed: \(authError?.localizedDescription ?? "Unknown error")")
                        if let error = authError as NSError? {
                            if error.code == LAError.userCancel.rawValue {
                                // User cancelled, don't show error
                                return
                            }
                        }
                        passcodeErrorMessage = authError?.localizedDescription ?? "onboarding.enable_biometric".localized
                        showingPasscodeError = true
                    }
                }
            }
        } else {
            print("Biometric not available: \(error?.localizedDescription ?? "Unknown error")")
            passcodeErrorMessage = "onboarding.enable_biometric".localized
            showingPasscodeError = true
        }
    }
    
    private func saveSettings(enableLock: Bool) {
        print("Saving settings - enableLock: \(enableLock)")
        
        userSettings.settings.isAppLockEnabled = enableLock
        
        if enableLock {
            userSettings.settings.appLockMethod = selectedLockMethod
            if selectedLockMethod == .passcode && !passcode.isEmpty {
                userSettings.settings.appPasscode = passcode
            }
        }
        
        print("Setting hasCompletedOnboarding = true")
        userSettings.settings.hasCompletedOnboarding = true
        
        // Force save to UserDefaults
        if let encoded = try? JSONEncoder().encode(userSettings.settings) {
            UserDefaults.standard.set(encoded, forKey: "BodyLapseUserSettings")
            UserDefaults.standard.synchronize()
        }
        
        print("Onboarding complete")
        // The view will automatically change due to hasCompletedOnboarding = true
    }
}

struct BaselinePhotoCaptureView: View {
    let onPhotoCapture: (Photo) -> Void
    @State private var cameraController: SimpleCameraViewController?
    @State private var isProcessing = false
    @State private var capturedImage: UIImage?
    @State private var detectedContour: [CGPoint]?
    @State private var showingContourConfirmation = false
    @State private var contourError: String?
    @State private var shouldShowCamera = true
    
    init(onPhotoCapture: @escaping (Photo) -> Void) {
        self.onPhotoCapture = onPhotoCapture
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
                    // Camera switch button at top
                    HStack {
                        Spacer()
                        Button(action: {
                            guard let controller = cameraController else { return }
                            controller.switchCamera()
                        }) {
                            Image(systemName: "camera.rotate")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .padding()
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .disabled(cameraController == nil)
                        .opacity(cameraController == nil ? 0.5 : 1.0)
                        .padding(.trailing, 20)
                        .padding(.top, 60)
                    }
                    
                    Spacer()
                
                    VStack(spacing: 20) {
                        Text("onboarding.first_photo.title".localized)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                        
                        Text("onboarding.first_photo.subtitle".localized)
                            .font(.body)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .shadow(radius: 2)
                        
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
                        .disabled(isProcessing || cameraController == nil)
                        .opacity(isProcessing || cameraController == nil ? 0.5 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: cameraController == nil)
                        .padding(.bottom, 40)
                    }
                    .padding()
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
                    print("BaselinePhotoCaptureView: Detected \(contour.count) contour points")
                    self.detectedContour = contour
                    self.isProcessing = false
                    self.showingContourConfirmation = true
                    
                case .failure(let error):
                    print("Failed to detect body contour: \(error)")
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
                print("Failed to save baseline photo: \(error)")
                DispatchQueue.main.async { [self] in
                    self.isProcessing = false
                }
            }
        }
    }
}

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