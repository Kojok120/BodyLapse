import Foundation
import StoreKit
import Combine

/// 本番用の一元管理サブスクリプションサービス
/// このサービスは全てのプレミアムサブスクリプション状態管理を処理し、
/// アプリ全体でプレミアムステータスの単一の真実の情報源を提供
@MainActor
class SubscriptionManagerService: ObservableObject {
    static let shared = SubscriptionManagerService()
    
    // MARK: - 公開プロパティ
    #if DEBUG
    @Published var isPremium: Bool = false
    #else
    @Published private(set) var isPremium: Bool = false
    #endif
    @Published private(set) var isLoadingSubscriptionStatus: Bool = false
    @Published private(set) var activeSubscriptionID: String?
    @Published private(set) var expirationDate: Date?
    @Published private(set) var isInTrialPeriod: Bool = false
    @Published private(set) var subscriptionError: String?
    
    // MARK: - プライベートプロパティ
    private let storeManager = StoreManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var statusUpdateTask: Task<Void, Never>?
    
    // MARK: - 初期化
    private init() {
        // Initializing SubscriptionManagerService...
        #if DEBUG
        // デバッグモードではプレミアムが手動で有効化されたか確認
        self.isPremium = UserDefaults.standard.bool(forKey: "debug_isPremium")
        #endif
        
        // 初期セットアップ
        Task {
            await initializeSubscriptionStatus()
        }
        
        // StoreManagerの変更を監視
        observeStoreManagerChanges()
    }
    
    deinit {
        statusUpdateTask?.cancel()
    }
    
    // MARK: - 公開メソッド
    
    /// App Storeから製品を読み込み
    func loadProducts() async {
        // Loading products...
        await storeManager.loadProducts()
        // Products loaded
    }
    
    /// サブスクリプション製品を購入
    func purchase(_ product: Product) async throws {
        subscriptionError = nil
        do {
            try await storeManager.purchase(product)
            await updateSubscriptionStatus()
        } catch {
            subscriptionError = error.localizedDescription
            throw error
        }
    }
    
    /// 過去の購入を復元
    func restorePurchases() async throws {
        subscriptionError = nil
        await storeManager.restorePurchases()
        await updateSubscriptionStatus()
        
        if !isPremium {
            let error = NSError(domain: "SubscriptionManager", 
                               code: 1001, 
                               userInfo: [NSLocalizedDescriptionKey: "No active subscriptions found"])
            subscriptionError = error.localizedDescription
            throw error
        }
    }
    
    /// App Storeからサブスクリプションステータスを更新
    func refreshSubscriptionStatus() async {
        await updateSubscriptionStatus()
    }
    
    /// 利用可能なサブスクリプション製品を取得
    var products: [Product] {
        storeManager.products
    }
    
    /// 製品が読み込み中か確認
    var isLoadingProducts: Bool {
        storeManager.isLoadingProducts
    }
    
    // MARK: - プレミアム機能確認
    
    /// ユーザーが体重記録機能にアクセスできるか確認
    func canAccessWeightTracking() -> Bool {
        return true // Now available for all users
    }
    
    /// 動画からウォーターマークを削除すべきか確認
    func canRemoveWatermark() -> Bool {
        return true // No watermark for all users
    }
    
    /// 広告を表示すべきか確認
    func shouldShowAds() -> Bool {
        return !isPremium // Only premium feature is ad removal
    }
    
    /// ユーザーが高度なチャート機能にアクセスできるか確認
    func canAccessAdvancedCharts() -> Bool {
        return true // Now available for all users
    }
    
    // MARK: - プライベートメソッド
    
    private func initializeSubscriptionStatus() async {
        // Initializing subscription status...
        isLoadingSubscriptionStatus = true
        await loadProducts()
        await updateSubscriptionStatus()
        isLoadingSubscriptionStatus = false
        // Initialization complete
    }
    
    private func observeStoreManagerChanges() {
        // purchasedProductIDsの変更を監視
        storeManager.$purchasedProductIDs
            .sink { [weak self] _ in
                Task {
                    await self?.updateSubscriptionStatus()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateSubscriptionStatus() async {
        #if DEBUG
        // デバッグモードでは手動設定のプレミアムステータスをUserDefaultsで確認
        let debugPremium = UserDefaults.standard.bool(forKey: "debug_isPremium")
        if debugPremium {
            await MainActor.run {
                let previousStatus = self.isPremium
                self.isPremium = true
                self.activeSubscriptionID = "debug.premium"
                self.expirationDate = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days from now
                self.isInTrialPeriod = false
                
                if previousStatus != self.isPremium {
                    NotificationCenter.default.post(name: .premiumStatusChanged, object: nil)
                }
            }
            return
        }
        #endif
        
        // Updating subscription status...
        // 現在のトランザクションステータスを取得
        var hasActiveSubscription = false
        var latestTransaction: Transaction?
        var subscriptionID: String?
        
        var transactionCount = 0
        for await result in Transaction.currentEntitlements {
            transactionCount += 1
            guard case .verified(let transaction) = result else { 
                // 未検証のトランザクションが見つかりました
                continue 
            }
            
            // トランザクションを確認
            // サブスクリプション製品か確認
            if transaction.productID == StoreProducts.premiumMonthly {
                // Found premium monthly subscription
                
                // サブスクリプションが取り消されていないか確認
                if transaction.revocationDate == nil {
                    hasActiveSubscription = true
                    subscriptionID = transaction.productID
                    // アクティブなサブスクリプションが見つかりました
                    
                    // 最新のトランザクションを保持
                    if latestTransaction == nil || transaction.purchaseDate > latestTransaction!.purchaseDate {
                        latestTransaction = transaction
                    }
                } else {
                    // サブスクリプションが取り消された
                }
            }
        }
        // Total transactions checked: \(transactionCount)
        
        // メインスレッドでプロパティを更新
        await MainActor.run {
            let previousStatus = self.isPremium
            self.isPremium = hasActiveSubscription
            self.activeSubscriptionID = subscriptionID
            
            // トランザクションがある場合、有効期限とトライアルステータスを更新
            if let transaction = latestTransaction {
                self.expirationDate = transaction.expirationDate
                self.isInTrialPeriod = transaction.offerType == .introductory
            } else {
                self.expirationDate = nil
                self.isInTrialPeriod = false
            }
            
            // ステータスが変更された場合、通知を送信
            if previousStatus != self.isPremium {
                NotificationCenter.default.post(name: .premiumStatusChanged, object: nil)
            }
        }
    }
    
    // MARK: - デバッグサポート
    
    #if DEBUG
    /// デバッグ用にプレミアムステータスをトグル
    func toggleDebugPremium() {
        let newStatus = !isPremium
        UserDefaults.standard.set(newStatus, forKey: "debug_isPremium")
        UserDefaults.standard.synchronize()
        
        isPremium = newStatus
        if newStatus {
            activeSubscriptionID = "debug.premium"
            expirationDate = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days from now
        } else {
            activeSubscriptionID = nil
            expirationDate = nil
        }
        
        NotificationCenter.default.post(name: .premiumStatusChanged, object: nil)
    }
    
    /// デバッグプレミアムステータスをリセット
    func resetDebugPremium() {
        UserDefaults.standard.removeObject(forKey: "debug_isPremium")
        UserDefaults.standard.synchronize()
        
        Task {
            await updateSubscriptionStatus()
        }
    }
    #endif
}

// MARK: - コンビニエンスメソッド
extension SubscriptionManagerService {
    /// 人間が読みやすいサブスクリプションステータスを取得
    var subscriptionStatusDescription: String {
        guard isPremium else { return "Free" }
        
        if let subscriptionID = activeSubscriptionID {
            if subscriptionID == StoreProducts.premiumMonthly {
                return "Premium Monthly"
            } else {
                return "Premium"
            }
        }
        
        return "Premium"
    }
    
    /// サブスクリプションが期限切れ間近か確認（3日以内）
    var isAboutToExpire: Bool {
        guard let expirationDate = expirationDate else { return false }
        let daysUntilExpiration = Calendar.current.dateComponents([.day], 
                                                                  from: Date(), 
                                                                  to: expirationDate).day ?? 0
        return daysUntilExpiration <= 3 && daysUntilExpiration >= 0
    }
}
