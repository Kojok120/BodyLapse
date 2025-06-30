import Foundation
import LocalAuthentication
import Security

class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()
    
    @Published var isAuthenticated = false
    @Published var authenticationError: String?
    @Published var isAuthenticationEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isAuthenticationEnabled, forKey: authEnabledKey)
        }
    }
    @Published var isBiometricEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isBiometricEnabled, forKey: biometricEnabledKey)
        }
    }
    
    private let passwordKey = "BodyLapsePassword"
    private let authEnabledKey = "AuthenticationEnabled"
    private let biometricEnabledKey = "BiometricAuthenticationEnabled"
    
    private init() {
        // Reset authentication state on app launch to prevent frozen state
        isAuthenticated = false
        authenticationError = nil
        // Load saved settings
        isAuthenticationEnabled = UserDefaults.standard.bool(forKey: authEnabledKey)
        isBiometricEnabled = UserDefaults.standard.bool(forKey: biometricEnabledKey)
    }
    
    
    var hasPassword: Bool {
        return getStoredPassword() != nil
    }
    
    var biometricType: LABiometryType {
        let context = LAContext()
        context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }
    
    var biometricTypeString: String {
        switch biometricType {
        case .faceID:
            return "settings.face_id".localized
        case .touchID:
            return "settings.touch_id".localized
        case .none:
            return "settings.biometric".localized
        @unknown default:
            return "settings.biometric".localized
        }
    }
    
    // MARK: - Password Management
    
    func setPassword(_ password: String) -> Bool {
        guard !password.isEmpty else { return false }
        
        guard let passwordData = password.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: passwordKey,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing password first
        SecItemDelete(query as CFDictionary)
        
        // Add new password
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func updatePassword(currentPassword: String, newPassword: String) -> Bool {
        guard verifyPassword(currentPassword) else { return false }
        return setPassword(newPassword)
    }
    
    func verifyPassword(_ password: String) -> Bool {
        guard let storedPassword = getStoredPassword() else { return false }
        return password == storedPassword
    }
    
    private func getStoredPassword() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: passwordKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess,
           let data = dataTypeRef as? Data,
           let password = String(data: data, encoding: .utf8) {
            return password
        }
        
        return nil
    }
    
    func removePassword() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: passwordKey
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Authentication Methods
    
    func authenticateWithBiometric(completion: @escaping (Bool, Error?) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            completion(false, error)
            return
        }
        
        let reason = "Authenticate to access your photos"
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.isAuthenticated = true
                    completion(true, nil)
                } else {
                    self.authenticationError = error?.localizedDescription
                    completion(false, error)
                }
            }
        }
    }
    
    func authenticateWithPassword(_ password: String) -> Bool {
        let success = verifyPassword(password)
        if success {
            isAuthenticated = true
        } else {
            authenticationError = "Incorrect PIN"
        }
        return success
    }
    
    func authenticate(completion: @escaping (Bool) -> Void) {
        // If authentication is not enabled, just mark as authenticated
        guard isAuthenticationEnabled else {
            isAuthenticated = true
            completion(true)
            return
        }
        
        // Try biometric first if enabled
        if isBiometricEnabled {
            authenticateWithBiometric { success, error in
                if success {
                    completion(true)
                } else {
                    // Biometric failed, user needs to enter password
                    completion(false)
                }
            }
        } else {
            // Biometric not enabled, user needs to enter password
            completion(false)
        }
    }
    
    func logout() {
        isAuthenticated = false
        authenticationError = nil
    }
}