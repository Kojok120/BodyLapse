import Foundation
import StoreKit

// MARK: - Product Identifiers
enum StoreProducts {
    static let premiumMonthly = "com.J.BodyLapse.premium.monthly"
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
        print("[StoreKit] StoreManager initialized")
        // Start transaction listener
        updates = observeTransactionUpdates()
    }
    
    deinit {
        updates?.cancel()
    }
    
    // MARK: - Load Products
    func loadProducts() async {
        print("[StoreKit] Starting to load products...")
        print("[StoreKit] Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
        print("[StoreKit] StoreKit Configuration: \(ProcessInfo.processInfo.arguments.contains("STOREKIT_ENABLED") ? "Enabled" : "Not detected")")
        
        isLoadingProducts = true
        purchaseError = nil
        
        do {
            print("[StoreKit] Requesting products with IDs: [\(StoreProducts.premiumMonthly)]")
            let products = try await Product.products(for: [
                StoreProducts.premiumMonthly
            ])
            
            print("[StoreKit] Successfully loaded \(products.count) products")
            if products.isEmpty {
                print("[StoreKit] WARNING: No products returned from App Store")
                print("[StoreKit] This could mean:")
                print("[StoreKit] 1. StoreKit configuration file is not properly set up")
                print("[StoreKit] 2. Product IDs don't match between code and App Store Connect")
                print("[StoreKit] 3. Products are not approved in App Store Connect")
                print("[StoreKit] 4. Running in simulator without StoreKit configuration")
            }
            
            for product in products {
                print("[StoreKit] Product loaded: \(product.id) - \(product.displayName) - \(product.displayPrice)")
            }
            
            await MainActor.run {
                self.products = products
                self.isLoadingProducts = false
            }
            
            await updatePurchasedProducts()
        } catch {
            print("[StoreKit] Error loading products: \(error)")
            print("[StoreKit] Error type: \(type(of: error))")
            print("[StoreKit] Error details: \(error.localizedDescription)")
            
            if let nsError = error as NSError? {
                print("[StoreKit] Error domain: \(nsError.domain)")
                print("[StoreKit] Error code: \(nsError.code)")
                print("[StoreKit] Error userInfo: \(nsError.userInfo)")
            }
            
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
        print("[StoreKit] Updating purchased products...")
        var purchasedProducts: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                print("[StoreKit] Transaction verification failed")
                continue
            }
            
            print("[StoreKit] Found transaction: \(transaction.productID) - Revoked: \(transaction.revocationDate != nil)")
            if transaction.revocationDate == nil {
                purchasedProducts.insert(transaction.productID)
                print("[StoreKit] Added active subscription: \(transaction.productID)")
            }
        }
        
        print("[StoreKit] Total active subscriptions: \(purchasedProducts.count)")
        
        await MainActor.run {
            let previousProducts = self.purchasedProductIDs
            self.purchasedProductIDs = purchasedProducts
            
            // Send notification if premium status changed
            if previousProducts != purchasedProducts {
                print("[StoreKit] Premium status changed - sending notification")
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