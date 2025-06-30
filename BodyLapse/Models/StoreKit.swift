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
    
    private var updates: Task<Void, Never>? = nil
    
    init() {
        // StoreManager initialized
        // Start transaction listener
        updates = observeTransactionUpdates()
    }
    
    deinit {
        updates?.cancel()
    }
    
    // MARK: - Load Products
    func loadProducts() async {
        // Starting to load products...
        // Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")
        // StoreKit Configuration check removed
        
        isLoadingProducts = true
        purchaseError = nil
        
        do {
            // Requesting products with IDs
            let products = try await Product.products(for: [
                StoreProducts.premiumMonthly
            ])
            
            // Successfully loaded products
            if products.isEmpty {
                // WARNING: No products returned from App Store
            }
            
            for product in products {
                // Product loaded: \(product.id)
            }
            
            await MainActor.run {
                self.products = products
                self.isLoadingProducts = false
            }
            
            await updatePurchasedProducts()
        } catch {
            // Error loading products
            
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
        // Updating purchased products...
        var purchasedProducts: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                // Transaction verification failed
                continue
            }
            
            // Found transaction: \(transaction.productID)
            if transaction.revocationDate == nil {
                purchasedProducts.insert(transaction.productID)
                // Added active subscription
            }
        }
        
        // Total active subscriptions: \(purchasedProducts.count)
        
        await MainActor.run {
            let previousProducts = self.purchasedProductIDs
            self.purchasedProductIDs = purchasedProducts
            
            // Send notification if premium status changed
            if previousProducts != purchasedProducts {
                // Premium status changed - sending notification
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
                    // Transaction failed verification
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