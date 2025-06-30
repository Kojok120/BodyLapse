import Foundation
import StoreKit
import Combine

/// Centralized subscription management service for production use
/// This service handles all premium subscription state management and provides
/// a single source of truth for premium status throughout the app
@MainActor
class SubscriptionManagerService: ObservableObject {
    static let shared = SubscriptionManagerService()
    
    // MARK: - Published Properties
    @Published private(set) var isPremium: Bool = false
    @Published private(set) var isLoadingSubscriptionStatus: Bool = false
    @Published private(set) var activeSubscriptionID: String?
    @Published private(set) var expirationDate: Date?
    @Published private(set) var isInTrialPeriod: Bool = false
    @Published private(set) var subscriptionError: String?
    
    // MARK: - Private Properties
    private let storeManager = StoreManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var statusUpdateTask: Task<Void, Never>?
    
    // MARK: - Initialization
    private init() {
        // Initializing SubscriptionManagerService...
        // Initial setup
        Task {
            await initializeSubscriptionStatus()
        }
        
        // Observe StoreManager changes
        observeStoreManagerChanges()
    }
    
    deinit {
        statusUpdateTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Load products from App Store
    func loadProducts() async {
        // Loading products...
        await storeManager.loadProducts()
        // Products loaded
    }
    
    /// Purchase a subscription product
    func purchase(_ product: Product) async throws {
        subscriptionError = nil
        do {
            try await storeManager.purchase(product)
            await updateSubscriptionStatus()
            
            // Send notification for successful purchase
            NotificationCenter.default.post(name: .premiumStatusChanged, object: nil)
        } catch {
            subscriptionError = error.localizedDescription
            throw error
        }
    }
    
    /// Restore previous purchases
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
        
        // Send notification for restored purchases
        NotificationCenter.default.post(name: .premiumStatusChanged, object: nil)
    }
    
    /// Refresh subscription status from App Store
    func refreshSubscriptionStatus() async {
        await updateSubscriptionStatus()
    }
    
    /// Get available subscription products
    var products: [Product] {
        storeManager.products
    }
    
    /// Check if products are being loaded
    var isLoadingProducts: Bool {
        storeManager.isLoadingProducts
    }
    
    // MARK: - Premium Features Check
    
    /// Check if user can access weight tracking feature
    func canAccessWeightTracking() -> Bool {
        return isPremium
    }
    
    /// Check if watermark should be removed from videos
    func canRemoveWatermark() -> Bool {
        return isPremium
    }
    
    /// Check if ads should be shown
    func shouldShowAds() -> Bool {
        return !isPremium
    }
    
    /// Check if user can access advanced chart features
    func canAccessAdvancedCharts() -> Bool {
        return isPremium
    }
    
    // MARK: - Private Methods
    
    private func initializeSubscriptionStatus() async {
        // Initializing subscription status...
        isLoadingSubscriptionStatus = true
        await loadProducts()
        await updateSubscriptionStatus()
        isLoadingSubscriptionStatus = false
        // Initialization complete
    }
    
    private func observeStoreManagerChanges() {
        // Observe purchasedProductIDs changes
        storeManager.$purchasedProductIDs
            .sink { [weak self] _ in
                Task {
                    await self?.updateSubscriptionStatus()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateSubscriptionStatus() async {
        // Updating subscription status...
        // Get current transaction status
        var hasActiveSubscription = false
        var latestTransaction: Transaction?
        var subscriptionID: String?
        
        var transactionCount = 0
        for await result in Transaction.currentEntitlements {
            transactionCount += 1
            guard case .verified(let transaction) = result else { 
                // Unverified transaction found
                continue 
            }
            
            // Checking transaction
            // Check if this is a subscription product
            if transaction.productID == StoreProducts.premiumMonthly {
                // Found premium monthly subscription
                
                // Check if subscription is not revoked
                if transaction.revocationDate == nil {
                    hasActiveSubscription = true
                    subscriptionID = transaction.productID
                    // Active subscription found
                    
                    // Keep the latest transaction
                    if latestTransaction == nil || transaction.purchaseDate > latestTransaction!.purchaseDate {
                        latestTransaction = transaction
                    }
                } else {
                    // Subscription revoked
                }
            }
        }
        // Total transactions checked: \(transactionCount)
        
        // Update properties on main thread
        await MainActor.run {
            let previousStatus = self.isPremium
            self.isPremium = hasActiveSubscription
            self.activeSubscriptionID = subscriptionID
            
            // Update expiration date and trial status if we have a transaction
            if let transaction = latestTransaction {
                self.expirationDate = transaction.expirationDate
                self.isInTrialPeriod = transaction.offerType == .introductory
            } else {
                self.expirationDate = nil
                self.isInTrialPeriod = false
            }
            
            // Send notification if status changed
            if previousStatus != self.isPremium {
                NotificationCenter.default.post(name: .premiumStatusChanged, object: nil)
            }
        }
    }
    
    // MARK: - Debug Support
}

// MARK: - Convenience Methods
extension SubscriptionManagerService {
    /// Get human-readable subscription status
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
    
    /// Check if subscription is about to expire (within 3 days)
    var isAboutToExpire: Bool {
        guard let expirationDate = expirationDate else { return false }
        let daysUntilExpiration = Calendar.current.dateComponents([.day], 
                                                                  from: Date(), 
                                                                  to: expirationDate).day ?? 0
        return daysUntilExpiration <= 3 && daysUntilExpiration >= 0
    }
}