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
                    Text("Create a PIN")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("This 4-digit PIN will be used to unlock your app when biometric authentication is not available.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 15) {
                        SecureField("4-digit PIN", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .onChange(of: password) { _, newValue in
                                // Limit to 4 digits
                                if newValue.count > 4 {
                                    password = String(newValue.prefix(4))
                                }
                            }
                        
                        SecureField("Confirm PIN", text: $confirmPassword)
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
                        Label("4 digits required", systemImage: password.count == 4 ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundColor(password.count == 4 ? .green : .secondary)
                        
                        Label("PINs match", systemImage: passwordsMatch ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundColor(passwordsMatch ? .green : .secondary)
                    }
                }
                .padding()
                
                Spacer()
                
                Button(action: savePassword) {
                    Text("Set PIN")
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
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
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
            errorMessage = "Failed to save PIN. Please try again."
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
                    Text("Change PIN")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 15) {
                        SecureField("Current PIN", text: $currentPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .onChange(of: currentPassword) { _, newValue in
                                if newValue.count > 4 {
                                    currentPassword = String(newValue.prefix(4))
                                }
                            }
                        
                        Divider()
                        
                        SecureField("New PIN", text: $newPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .onChange(of: newPassword) { _, newValue in
                                if newValue.count > 4 {
                                    newPassword = String(newValue.prefix(4))
                                }
                            }
                        
                        SecureField("Confirm New PIN", text: $confirmPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .onChange(of: confirmPassword) { _, newValue in
                                if newValue.count > 4 {
                                    confirmPassword = String(newValue.prefix(4))
                                }
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Label("4 digits required", systemImage: newPassword.count == 4 ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundColor(newPassword.count == 4 ? .green : .secondary)
                        
                        Label("PINs match", systemImage: passwordsMatch ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundColor(passwordsMatch ? .green : .secondary)
                    }
                }
                .padding()
                
                Spacer()
                
                Button(action: changePassword) {
                    Text("Change PIN")
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
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("PIN changed successfully")
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
            errorMessage = "Current PIN is incorrect"
            showingError = true
        }
    }
}