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
    /// 現在のサブスクリプションのティア（free / standard / pro）。
    @Published private(set) var tier: SubscriptionTier = .free
    @Published private(set) var isLoadingSubscriptionStatus: Bool = false
    @Published private(set) var activeSubscriptionID: String?
    @Published private(set) var expirationDate: Date?
    @Published private(set) var isInTrialPeriod: Bool = false
    @Published private(set) var subscriptionError: String?

    /// 有料（Standard以上）か。広告削除など既存の判定に使う（後方互換）。
    var isPremium: Bool { tier != .free }
    /// Proプランか。クラウドバックアップ・高度な動画などPro限定機能の判定に使う。
    var isPro: Bool { tier == .pro }
    
    // MARK: - プライベートプロパティ
    private let storeManager = StoreManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var statusUpdateTask: Task<Void, Never>?
    
    // MARK: - 初期化
    private init() {
        // Initializing SubscriptionManagerService...
        #if DEBUG
        // デバッグモードで手動設定されたティアを反映
        self.tier = Self.debugTier()
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

    // MARK: - Pro限定機能

    /// クラウドバックアップ（Pro限定）を利用できるか。
    func canAccessCloudBackup() -> Bool {
        return isPro
    }

    /// 高度な動画/SNS共有エクスポート（Pro限定）を利用できるか。
    func canAccessAdvancedVideo() -> Bool {
        return isPro
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
                // 連続更新で重いステータス更新Taskが積み上がらないよう、前のTaskをキャンセルしてから起動
                self?.statusUpdateTask?.cancel()
                self?.statusUpdateTask = Task {
                    await self?.updateSubscriptionStatus()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateSubscriptionStatus() async {
        #if DEBUG
        // デバッグモードでは手動設定のティアをUserDefaultsで確認
        let forcedTier = Self.debugTier()
        if forcedTier != .free {
            await MainActor.run {
                let previousTier = self.tier
                self.tier = forcedTier
                self.activeSubscriptionID = forcedTier == .pro ? "debug.pro" : "debug.standard"
                self.expirationDate = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days from now
                self.isInTrialPeriod = false

                if previousTier != self.tier {
                    NotificationCenter.default.post(name: .premiumStatusChanged, object: nil)
                }
            }
            return
        }
        #endif

        // 現在のエンタイトルメントから最上位のティアを判定する
        var highestTier: SubscriptionTier = .free
        var latestTransaction: Transaction?
        var subscriptionID: String?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }

            let productTier = SubscriptionTier.tier(for: transaction.productID)
            guard productTier != .free else { continue }

            // より上位のティア、または同ティアで購入が新しいものを採用
            let isHigherTier = productTier > highestTier
            let isNewerSameTier = productTier == highestTier &&
                (latestTransaction == nil || transaction.purchaseDate > latestTransaction!.purchaseDate)
            if isHigherTier || isNewerSameTier {
                highestTier = productTier
                subscriptionID = transaction.productID
                latestTransaction = transaction
            }
        }

        // メインスレッドでプロパティを更新
        await MainActor.run {
            let previousTier = self.tier
            self.tier = highestTier
            self.activeSubscriptionID = subscriptionID

            // トランザクションがある場合、有効期限とトライアルステータスを更新
            if let transaction = latestTransaction {
                self.expirationDate = transaction.expirationDate
                self.isInTrialPeriod = transaction.offerType == .introductory
            } else {
                self.expirationDate = nil
                self.isInTrialPeriod = false
            }

            // ティアが変更された場合、通知を送信
            if previousTier != self.tier {
                NotificationCenter.default.post(name: .premiumStatusChanged, object: nil)
            }
        }
    }
    
    // MARK: - デバッグサポート
    
    #if DEBUG
    /// UserDefaultsから現在のデバッグティアを取得
    static func debugTier() -> SubscriptionTier {
        if UserDefaults.standard.bool(forKey: "debug_isPro") { return .pro }
        if UserDefaults.standard.bool(forKey: "debug_isPremium") { return .standard }
        return .free
    }

    /// デバッグ用にStandard（広告削除）をトグル
    func toggleDebugPremium() {
        let enable = (tier == .free)
        UserDefaults.standard.set(enable, forKey: "debug_isPremium")
        UserDefaults.standard.set(false, forKey: "debug_isPro")
        UserDefaults.standard.synchronize()

        tier = enable ? .standard : .free
        activeSubscriptionID = enable ? "debug.standard" : nil
        expirationDate = enable ? Date().addingTimeInterval(30 * 24 * 60 * 60) : nil

        NotificationCenter.default.post(name: .premiumStatusChanged, object: nil)
    }

    /// デバッグ用にPro（クラウド・高度動画）をトグル
    func toggleDebugPro() {
        let enable = (tier != .pro)
        UserDefaults.standard.set(enable, forKey: "debug_isPro")
        if enable { UserDefaults.standard.set(false, forKey: "debug_isPremium") }
        UserDefaults.standard.synchronize()

        tier = enable ? .pro : .free
        activeSubscriptionID = enable ? "debug.pro" : nil
        expirationDate = enable ? Date().addingTimeInterval(30 * 24 * 60 * 60) : nil

        NotificationCenter.default.post(name: .premiumStatusChanged, object: nil)
    }

    /// デバッグティアをリセット
    func resetDebugPremium() {
        UserDefaults.standard.removeObject(forKey: "debug_isPremium")
        UserDefaults.standard.removeObject(forKey: "debug_isPro")
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
        switch tier {
        case .pro: return "Pro"
        case .standard: return "Standard"
        case .free: return "Free"
        }
    }
    
    /// サブスクリプションが期限切れ間近か確認（3日以内）
    var isAboutToExpire: Bool {
        guard let days = daysUntilExpiration else { return false }
        return days <= 3
    }

    /// 有効期限（次回更新日）までの残り日数。期限が無い場合はnil。
    var daysUntilExpiration: Int? {
        guard let expirationDate = expirationDate else { return nil }
        guard let days = Calendar.current.dateComponents([.day],
                                                         from: Date(),
                                                         to: expirationDate).day else { return nil }
        return max(0, days)
    }
}
