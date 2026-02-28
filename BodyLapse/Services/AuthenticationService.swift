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
        // アプリ起動時に認証状態をリセットしてフリーズ状態を防止
        isAuthenticated = false
        authenticationError = nil
        // 保存された設定を読み込み
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
        case .opticID:
            return "settings.face_id".localized
        case .none:
            return "settings.biometric".localized
        @unknown default:
            return "settings.biometric".localized
        }
    }
    
    // MARK: - パスワード管理
    
    func setPassword(_ password: String) -> Bool {
        guard !password.isEmpty else { return false }
        
        guard let passwordData = password.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: passwordKey,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // 既存のパスワードをまず削除
        SecItemDelete(query as CFDictionary)
        
        // 新しいパスワードを追加
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
    
    // MARK: - 認証メソッド
    
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
        // 認証が有効でない場合は認証済みとしてマーク
        guard isAuthenticationEnabled else {
            isAuthenticated = true
            completion(true)
            return
        }
        
        // 生体認証が有効な場合はまず試行
        if isBiometricEnabled {
            authenticateWithBiometric { success, error in
                if success {
                    completion(true)
                } else {
                    // 生体認証失敗、パスワード入力が必要
                    completion(false)
                }
            }
        } else {
            // 生体認証が無効、パスワード入力が必要
            completion(false)
        }
    }
    
    func logout() {
        isAuthenticated = false
        authenticationError = nil
    }
}
