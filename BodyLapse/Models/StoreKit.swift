import Foundation
import StoreKit

// MARK: - Product Identifiers
enum StoreProducts {
    static let premiumMonthly = "com.J.BodyLapse.premium.monthly"
    static let premiumYearly = "com.J.BodyLapse.premium.yearly"
}

// MARK: - Store Manager
@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs = Set<String>()
    @Published var isLoadingProducts = false
    @Published var purchaseError: String?
    
    #if DEBUG
    // Debug mode for testing without actual purchases
    static var debugMode = false
    static var debugPremiumStatus = false
    #endif
    
    private var updates: Task<Void, Never>? = nil
    
    init() {
        // Start transaction listener
        updates = observeTransactionUpdates()
    }
    
    deinit {
        updates?.cancel()
    }
    
    // MARK: - Load Products
    func loadProducts() async {
        isLoadingProducts = true
        purchaseError = nil
        
        do {
            let products = try await Product.products(for: [
                StoreProducts.premiumMonthly,
                StoreProducts.premiumYearly
            ])
            
            await MainActor.run {
                self.products = products.sorted { $0.price < $1.price }
                self.isLoadingProducts = false
            }
            
            await updatePurchasedProducts()
        } catch {
            await MainActor.run {
                self.purchaseError = "Failed to load products: \(error.localizedDescription)"
                self.isLoadingProducts = false
            }
        }
    }
    
    // MARK: - Purchase Product
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
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        try? await AppStore.sync()
        await updatePurchasedProducts()
    }
    
    // MARK: - Check Premium Status
    var isPremium: Bool {
        #if DEBUG
        if StoreManager.debugMode {
            return StoreManager.debugPremiumStatus
        }
        #endif
        return !purchasedProductIDs.isEmpty
    }
    
    var activePremiumProductID: String? {
        purchasedProductIDs.first
    }
    
    // MARK: - Private Methods
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    private func updatePurchasedProducts() async {
        var purchasedProducts: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            if transaction.revocationDate == nil {
                purchasedProducts.insert(transaction.productID)
            }
        }
        
        await MainActor.run {
            let previousProducts = self.purchasedProductIDs
            self.purchasedProductIDs = purchasedProducts
            
            // Send notification if premium status changed
            if previousProducts != purchasedProducts {
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
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }
}

// MARK: - Store Errors
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

// MARK: - Product Extensions
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