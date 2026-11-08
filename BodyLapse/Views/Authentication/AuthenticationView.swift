import SwiftUI
import LocalAuthentication

struct AuthenticationView: View {
    @StateObject private var authService = AuthenticationService.shared
    @State private var password = ""
    @State private var showingPasswordField = false
    @State private var isAuthenticating = false
    /// この端末に PIN があるか (機種変更すると PIN は移らず、ロックの設定だけが移る)
    @State private var hasPIN = true
    @State private var lockoutRemaining: TimeInterval = 0
    @State private var showingPINReset = false
    @State private var recoveryError: String?
    @Environment(\.dismiss) private var dismiss
    private let lockoutTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var onAuthenticated: () -> Void
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 40) {
                Spacer()
                
                // App Icon and Title
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.accentColor)
                    
                    Text("auth.app_name".localized)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("auth.enter_pin".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .opacity(showingPasswordField ? 1 : 0)
                }
                
                // Authentication UI
                VStack(spacing: 20) {
                    if !hasPIN {
                        // PIN がこの端末に無い。端末のパスコードで本人確認して作り直してもらう
                        Text("auth.no_pin_on_device".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Button(action: startRecovery) {
                            Text("auth.recover_with_device_passcode".localized)
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .cornerRadius(10)
                        }
                    } else if showingPasswordField {
                        SecureField("auth.enter_pin_short".localized, text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .submitLabel(.done)
                            .onSubmit {
                                authenticateWithPassword()
                            }
                            .onChange(of: password) { _, newValue in
                                // Limit to 4 digits
                                if newValue.count > 4 {
                                    password = String(newValue.prefix(4))
                                }
                            }
                        
                        Button(action: authenticateWithPassword) {
                            HStack {
                                Text("auth.unlock".localized)
                                Image(systemName: "lock.open.fill")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(10)
                        }
                        .disabled(password.isEmpty || isAuthenticating || lockoutRemaining > 0)
                        
                        if authService.isBiometricEnabled {
                            Button(action: authenticateWithBiometric) {
                                HStack {
                                    Text(authService.biometricType == .faceID ? "auth.use_faceid".localized : "auth.use_touchid".localized)
                                    Image(systemName: biometricIcon)
                                }
                                .font(.subheadline)
                                .foregroundColor(.accentColor)
                            }
                        }
                    } else if !isAuthenticating {
                        // Initial biometric prompt
                        VStack(spacing: 20) {
                            Button(action: authenticateWithBiometric) {
                                VStack(spacing: 10) {
                                    Image(systemName: biometricIcon)
                                        .font(.system(size: 50))
                                        .foregroundColor(.accentColor)
                                    
                                    Text(authService.biometricType == .faceID ? "auth.tap_faceid".localized : "auth.tap_touchid".localized)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            Button("auth.use_pin".localized) {
                                withAnimation {
                                    showingPasswordField = true
                                }
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    if lockoutRemaining > 0 {
                        Text(AuthenticationService.lockoutMessage(remaining: lockoutRemaining))
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    } else if let error = recoveryError ?? authService.authenticationError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    if hasPIN {
                        Button("auth.forgot_pin".localized, action: startRecovery)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
                Spacer()
            }
            
            if isAuthenticating {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
            }
        }
        .sheet(isPresented: $showingPINReset) {
            PasswordSetupView {
                authService.completeRecovery()
                onAuthenticated()
            }
        }
        .onReceive(lockoutTimer) { _ in
            if lockoutRemaining > 0 {
                lockoutRemaining = authService.pinLockoutRemaining
                if lockoutRemaining == 0 {
                    authService.authenticationError = nil
                }
            }
        }
        .onAppear {
            hasPIN = authService.hasPassword
            lockoutRemaining = authService.pinLockoutRemaining
            // Automatically try biometric authentication when view appears
            if authService.isBiometricEnabled && !showingPasswordField {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    authenticateWithBiometric()
                }
            } else {
                showingPasswordField = true
            }
        }
    }
    
    private var biometricIcon: String {
        switch authService.biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "lock.shield"
        }
    }
    
    private func authenticateWithBiometric() {
        isAuthenticating = true
        authService.authenticationError = nil
        
        authService.authenticateWithBiometric { success, error in
            isAuthenticating = false
            
            if success {
                onAuthenticated()
            } else if error != nil {
                // Show password field if biometric fails
                withAnimation {
                    showingPasswordField = true
                }
            }
        }
    }
    
    private func authenticateWithPassword() {
        guard !password.isEmpty, lockoutRemaining == 0 else { return }
        
        isAuthenticating = true
        authService.authenticationError = nil
        recoveryError = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAuthenticating = false
            
            switch authService.authenticateWithPassword(password) {
            case .success:
                onAuthenticated()
            case .incorrect:
                password = ""
            case .lockedOut(let remaining):
                password = ""
                lockoutRemaining = remaining
            }
        }
    }

    /// 端末のパスコードで本人確認し、PIN を作り直す
    private func startRecovery() {
        recoveryError = nil
        authService.verifyDeviceOwner { result in
            switch result {
            case .success:
                showingPINReset = true
            case .failure(let error):
                if let laError = error as? LAError {
                    switch laError.code {
                    case .userCancel, .appCancel, .systemCancel:
                        return
                    case .passcodeNotSet:
                        recoveryError = "auth.recovery_needs_passcode".localized
                        return
                    default:
                        break
                    }
                }
                recoveryError = error.localizedDescription
            }
        }
    }
}