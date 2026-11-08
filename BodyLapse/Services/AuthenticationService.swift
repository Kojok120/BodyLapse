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
    private let attemptStateKey = "BodyLapsePINAttemptState"
    private let authEnabledKey = "AuthenticationEnabled"
    private let biometricEnabledKey = "BiometricAuthenticationEnabled"

    /// PIN の照合結果
    enum PINAttemptResult: Equatable {
        case success
        /// 違う PIN。待ち時間に入るまでに残っている回数
        case incorrect(attemptsBeforeLockout: Int)
        /// 失敗が続いたので、しばらく試せない
        case lockedOut(remaining: TimeInterval)
    }

    /// 連続失敗の回数と、次に試せる時刻。再インストール後も引き継がないよう Keychain の ThisDeviceOnly に置く
    private struct AttemptState: Codable {
        var failureCount = 0
        var lockoutUntil: Date?
    }
    
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
        if status == errSecSuccess {
            resetAttemptState()
        }
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
        resetAttemptState()
    }

    // MARK: - 試行回数の制限

    private func loadAttemptState() -> AttemptState {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: attemptStateKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let state = try? JSONDecoder().decode(AttemptState.self, from: data) else {
            return AttemptState()
        }
        return state
    }

    private func saveAttemptState(_ state: AttemptState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: attemptStateKey
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private func resetAttemptState() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: attemptStateKey
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// 次に PIN を試せるまでの残り秒数 (0 なら今すぐ試せる)
    var pinLockoutRemaining: TimeInterval {
        PINAttemptPolicy.remainingLockout(until: loadAttemptState().lockoutUntil, now: Date())
    }
    
    // MARK: - 認証メソッド
    
    func authenticateWithBiometric(completion: @escaping (Bool, Error?) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            completion(false, error)
            return
        }
        
        let reason = "auth.biometric_reason".localized
        
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
    
    /// PIN で解除する。失敗が続くと待ち時間を課す (4 桁の総当たりを防ぐ)
    func authenticateWithPassword(_ password: String, now: Date = Date()) -> PINAttemptResult {
        var state = loadAttemptState()
        let remaining = PINAttemptPolicy.remainingLockout(until: state.lockoutUntil, now: now)
        if remaining > 0 {
            authenticationError = Self.lockoutMessage(remaining: remaining)
            return .lockedOut(remaining: remaining)
        }

        if verifyPassword(password) {
            resetAttemptState()
            authenticationError = nil
            isAuthenticated = true
            return .success
        }

        state.failureCount += 1
        let lockout = PINAttemptPolicy.lockoutDuration(afterFailures: state.failureCount)
        state.lockoutUntil = lockout > 0 ? now.addingTimeInterval(lockout) : nil
        saveAttemptState(state)

        if lockout > 0 {
            authenticationError = Self.lockoutMessage(remaining: lockout)
            return .lockedOut(remaining: lockout)
        }
        let attemptsLeft = PINAttemptPolicy.attemptsBeforeLockout(failureCount: state.failureCount)
        authenticationError = "auth.incorrect_pin".localized(with: attemptsLeft)
        return .incorrect(attemptsBeforeLockout: attemptsLeft)
    }

    static func lockoutMessage(remaining: TimeInterval) -> String {
        let seconds = Int(remaining.rounded(.up))
        let text = seconds >= 60
            ? "auth.lockout_minutes".localized(with: Int((Double(seconds) / 60).rounded(.up)))
            : "auth.lockout_seconds".localized(with: seconds)
        return text
    }

    // MARK: - PIN の復旧

    /// 端末のパスコード (または生体認証) で本人確認する。成功したら PIN を作り直してもらう
    func verifyDeviceOwner(completion: @escaping (Result<Void, Error>) -> Void) {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            completion(.failure(error ?? LAError(.passcodeNotSet)))
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "auth.recovery_reason".localized) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success(()))
                } else {
                    completion(.failure(error ?? LAError(.authenticationFailed)))
                }
            }
        }
    }

    /// 端末の本人確認のあと、新しい PIN を保存できたら解除する
    func completeRecovery() {
        resetAttemptState()
        authenticationError = nil
        isAuthenticated = true
    }
    
    func logout() {
        isAuthenticated = false
        authenticationError = nil
    }

    /// バックグラウンドに回ったらロックをかけ直す
    func lockIfNeeded() {
        if isAuthenticationEnabled {
            logout()
        }
    }
}
