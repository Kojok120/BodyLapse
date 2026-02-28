import Foundation
import StoreKit

// MARK: - プロダクト識別子
enum StoreProducts {
    static let premiumMonthly = "com.J.BodyLapse.premium.monthly"
}

// MARK: - ストアマネージャー
@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs = Set<String>()
    @Published var isLoadingProducts = false
    @Published var purchaseError: String?
    
    private var updates: Task<Void, Never>? = nil
    
    init() {
        // StoreManagerの初期化
        // トランザクションリスナーの開始
        updates = observeTransactionUpdates()
    }
    
    deinit {
        updates?.cancel()
    }
    
    // MARK: - プロダクトの読み込み
    func loadProducts() async {
        // プロダクトの読み込み開始...
        // Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")
        // StoreKit設定チェックは削除済み
        
        isLoadingProducts = true
        purchaseError = nil
        
        do {
            // IDを指定してプロダクトをリクエスト
            let products = try await Product.products(for: [
                StoreProducts.premiumMonthly
            ])
            
            // プロダクトの読み込み成功
            if products.isEmpty {
                // 警告: App Storeからプロダクトが返却されませんでした
            }
            
            for _ in products {
                // プロダクト読み込み完了: \(product.id)
            }
            
            await MainActor.run {
                self.products = products
                self.isLoadingProducts = false
            }
            
            await updatePurchasedProducts()
        } catch {
            // プロダクト読み込みエラー
            
            await MainActor.run {
                self.purchaseError = "Failed to load products: \(error.localizedDescription)"
                self.isLoadingProducts = false
            }
        }
    }
    
    // MARK: - プロダクトの購入
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            
            await updatePurchasedProducts()
            await transaction.finish()
            
        case .userCancelled:
            throw StoreError.userCancelled
            
        case .pending:
            throw StoreError.pending
            
        @unknown default:
            throw StoreError.unknown
        }
    }
    
    // MARK: - 購入の復元
    func restorePurchases() async {
        try? await AppStore.sync()
        await updatePurchasedProducts()
    }
    
    // MARK: - プレミアムステータスの確認
    var isPremium: Bool {
        return !purchasedProductIDs.isEmpty
    }
    
    var activePremiumProductID: String? {
        purchasedProductIDs.first
    }
    
    // MARK: - プライベートメソッド
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    private func updatePurchasedProducts() async {
        // 購入済みプロダクトを更新中...
        var purchasedProducts: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                // トランザクション検証失敗
                continue
            }
            
            // トランザクション検出: \(transaction.productID)
            if transaction.revocationDate == nil {
                purchasedProducts.insert(transaction.productID)
                // アクティブなサブスクリプションを追加
            }
        }
        
        // アクティブなサブスクリプション合計: \(purchasedProducts.count)
        
        await MainActor.run {
            let previousProducts = self.purchasedProductIDs
            self.purchasedProductIDs = purchasedProducts
            
            // プレミアムステータスが変更された場合に通知を送信
            if previousProducts != purchasedProducts {
                // プレミアムステータスが変更されました - 通知を送信
                NotificationCenter.default.post(name: .premiumStatusChanged, object: nil)
            }
        }
    }
    
    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    // トランザクション検証に失敗
                }
            }
        }
    }
}

// MARK: - ストアエラー
enum StoreError: LocalizedError {
    case failedVerification
    case userCancelled
    case pending
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        case .userCancelled:
            return "Purchase was cancelled"
        case .pending:
            return "Purchase is pending"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

// MARK: - プロダクト拡張
extension Product {
    var localizedPeriod: String {
        switch self.subscription?.subscriptionPeriod.unit {
        case .day:
            return "daily"
        case .week:
            return "weekly"
        case .month:
            return "monthly"
        case .year:
            return "yearly"
        default:
            return ""
        }
    }
    
    var localizedPriceString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: self.priceFormatStyle.locale.identifier)
        return formatter.string(from: self.price as NSDecimalNumber) ?? ""
    }
}