import SwiftUI
import LocalAuthentication

struct OnboardingView: View {
    @EnvironmentObject var userSettings: UserSettingsManager
    @State private var currentStep = 1
    
    // Goal setting
    @State private var targetWeight = ""
    @State private var targetBodyFat = ""
    
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
                progressIndicator
                
                TabView(selection: $currentStep) {
                    goalSettingStep
                        .tag(1)
                    
                    baselinePhotoStep
                        .tag(2)
                    
                    appLockStep
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                
                navigationButtons
            }
            .navigationTitle("Welcome to BodyLapse")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(currentStep == 2) // Hide for camera step
        }
        .interactiveDismissDisabled()
    }
    
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
    
    private var goalSettingStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
                .padding(.bottom, 20)
            
            Text("Set Your Goals")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Track your progress with target weight and body fat percentage")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                HStack {
                    Text("Target Weight")
                        .frame(width: 120, alignment: .leading)
                    TextField("Optional", text: $targetWeight)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Text(userSettings.settings.weightUnit.symbol)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Target Body Fat")
                        .frame(width: 120, alignment: .leading)
                    TextField("Optional", text: $targetBodyFat)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Text("%")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
            
            Spacer()
        }
        .padding()
        .onTapGesture {
            hideKeyboard()
        }
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
            
            Text("Secure Your Progress")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Protect your photos with Face ID or a passcode")
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
                        Text("Enable \(biometricName)")
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
                        Text("Set up Passcode")
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
        .alert("Passcode Error", isPresented: $showingPasscodeError) {
            Button("OK") { }
        } message: {
            Text(passcodeErrorMessage)
        }
    }
    
    private var navigationButtons: some View {
        HStack {
            if currentStep > 1 {
                Button("Back") {
                    hideKeyboard()
                    withAnimation {
                        currentStep -= 1
                    }
                }
                .padding()
            }
            
            Spacer()
            
            if currentStep == 1 {
                Button("Skip") {
                    hideKeyboard()
                    currentStep = 2
                }
                .padding()
                
                Button("Next") {
                    hideKeyboard()
                    saveGoals()
                    currentStep = 2
                }
                .padding()
                .disabled(targetWeight.isEmpty && targetBodyFat.isEmpty)
            } else if currentStep == 3 {
                Button("Skip") {
                    hideKeyboard()
                    saveSettings(enableLock: false)
                }
                .padding()
                
                Button("Finish") {
                    hideKeyboard()
                    saveSettings(enableLock: false)
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
    
    private func saveGoals() {
        if let weight = Double(targetWeight) {
            userSettings.settings.targetWeight = weight
        }
        if let bodyFat = Double(targetBodyFat) {
            userSettings.settings.targetBodyFatPercentage = bodyFat
        }
    }
    
    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        
        print("Checking biometric availability...")
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            print("Biometric available, type: \(context.biometryType.rawValue)")
            
            // Request authentication to ensure user grants permission
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Enable biometric authentication to secure your photos") { success, authError in
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
                        passcodeErrorMessage = authError?.localizedDescription ?? "Failed to enable biometric authentication"
                        showingPasscodeError = true
                    }
                }
            }
        } else {
            print("Biometric not available: \(error?.localizedDescription ?? "Unknown error")")
            passcodeErrorMessage = "Biometric authentication is not available on this device. Please use a passcode instead."
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
                        Text("Take Your First Photo")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                        
                        Text("Stand in the frame and capture your starting point")
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
                Section(header: Text("Create Passcode")) {
                    SecureField("Enter Passcode", text: $passcode)
                        .keyboardType(.numberPad)
                    
                    SecureField("Confirm Passcode", text: $confirmPasscode)
                        .keyboardType(.numberPad)
                }
                
                Section {
                    Text("Your passcode should be at least 4 digits")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Set Up Passcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        validateAndSave()
                    }
                    .disabled(passcode.isEmpty || confirmPasscode.isEmpty)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func validateAndSave() {
        guard passcode.count >= 4 else {
            errorMessage = "Passcode must be at least 4 digits"
            showingError = true
            return
        }
        
        guard passcode == confirmPasscode else {
            errorMessage = "Passcodes do not match"
            showingError = true
            return
        }
        
        onComplete()
        dismiss()
    }
}

#Preview {
    OnboardingView()
        .environmentObject(UserSettingsManager())
}