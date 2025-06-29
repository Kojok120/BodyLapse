import SwiftUI

struct PasswordSetupView: View {
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    let onPasswordSet: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("settings.change_pin".localized)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("onboarding.security.subtitle".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 15) {
                        SecureField("onboarding.enter_passcode".localized, text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .onChange(of: password) { _, newValue in
                                // Limit to 4 digits
                                if newValue.count > 4 {
                                    password = String(newValue.prefix(4))
                                }
                            }
                        
                        SecureField("onboarding.confirm_passcode".localized, text: $confirmPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .onChange(of: confirmPassword) { _, newValue in
                                // Limit to 4 digits
                                if newValue.count > 4 {
                                    confirmPassword = String(newValue.prefix(4))
                                }
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Label("onboarding.enter_passcode".localized, systemImage: password.count == 4 ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundColor(password.count == 4 ? .green : .secondary)
                        
                        Label("onboarding.confirm_passcode".localized, systemImage: passwordsMatch ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundColor(passwordsMatch ? .green : .secondary)
                    }
                }
                .padding()
                
                Spacer()
                
                Button(action: savePassword) {
                    Text("onboarding.setup_passcode".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isValidPassword ? Color.accentColor : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(!isValidPassword)
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
            }
            .alert("common.error".localized, isPresented: $showingError) {
                Button("common.ok".localized) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var passwordsMatch: Bool {
        !password.isEmpty && !confirmPassword.isEmpty && password == confirmPassword
    }
    
    private var isValidPassword: Bool {
        password.count == 4 && passwordsMatch && password.allSatisfy { $0.isNumber }
    }
    
    private func savePassword() {
        guard isValidPassword else { return }
        
        if AuthenticationService.shared.setPassword(password) {
            onPasswordSet()
            dismiss()
        } else {
            errorMessage = "common.error".localized
            showingError = true
        }
    }
}

struct ChangePasswordView: View {
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("settings.change_pin".localized)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 15) {
                        SecureField("auth.enter_pin_short".localized, text: $currentPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .onChange(of: currentPassword) { _, newValue in
                                if newValue.count > 4 {
                                    currentPassword = String(newValue.prefix(4))
                                }
                            }
                        
                        Divider()
                        
                        SecureField("onboarding.enter_passcode".localized, text: $newPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .onChange(of: newPassword) { _, newValue in
                                if newValue.count > 4 {
                                    newPassword = String(newValue.prefix(4))
                                }
                            }
                        
                        SecureField("onboarding.confirm_passcode".localized, text: $confirmPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .onChange(of: confirmPassword) { _, newValue in
                                if newValue.count > 4 {
                                    confirmPassword = String(newValue.prefix(4))
                                }
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Label("onboarding.enter_passcode".localized, systemImage: newPassword.count == 4 ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundColor(newPassword.count == 4 ? .green : .secondary)
                        
                        Label("onboarding.confirm_passcode".localized, systemImage: passwordsMatch ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundColor(passwordsMatch ? .green : .secondary)
                    }
                }
                .padding()
                
                Spacer()
                
                Button(action: changePassword) {
                    Text("settings.change_pin".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isValidPassword ? Color.accentColor : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(!isValidPassword)
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
            }
            .alert("common.error".localized, isPresented: $showingError) {
                Button("common.ok".localized) { }
            } message: {
                Text(errorMessage)
            }
            .alert("common.done".localized, isPresented: $showingSuccess) {
                Button("common.ok".localized) {
                    dismiss()
                }
            } message: {
                Text("common.done".localized)
            }
        }
    }
    
    private var passwordsMatch: Bool {
        !newPassword.isEmpty && !confirmPassword.isEmpty && newPassword == confirmPassword
    }
    
    private var isValidPassword: Bool {
        currentPassword.count == 4 && newPassword.count == 4 && passwordsMatch && 
        currentPassword.allSatisfy { $0.isNumber } && newPassword.allSatisfy { $0.isNumber }
    }
    
    private func changePassword() {
        guard isValidPassword else { return }
        
        if AuthenticationService.shared.updatePassword(currentPassword: currentPassword, newPassword: newPassword) {
            showingSuccess = true
        } else {
            errorMessage = "auth.enter_pin".localized
            showingError = true
        }
    }
}