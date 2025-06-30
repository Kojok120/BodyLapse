import SwiftUI
import StoreKit

@MainActor
class PremiumViewModel: ObservableObject {
    @Published var isShowingPremiumView = false
    @Published var isPurchasing = false
    @Published var purchaseError: String?
    
    private let subscriptionManager = SubscriptionManagerService.shared
    
    var products: [Product] {
        subscriptionManager.products
    }
    
    var isPremium: Bool {
        subscriptionManager.isPremium
    }
    
    var isLoadingProducts: Bool {
        subscriptionManager.isLoadingProducts
    }
    
    var subscriptionStatusDescription: String {
        subscriptionManager.subscriptionStatusDescription
    }
    
    var expirationDate: Date? {
        subscriptionManager.expirationDate
    }
    
    var isAboutToExpire: Bool {
        subscriptionManager.isAboutToExpire
    }
    
    func loadProducts() async {
        // Loading products...
        await subscriptionManager.loadProducts()
        // Products loaded
    }
    
    func purchase(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil
        
        do {
            try await subscriptionManager.purchase(product)
            isShowingPremiumView = false
        } catch {
            purchaseError = error.localizedDescription
        }
        
        isPurchasing = false
    }
    
    func restorePurchases() async {
        isPurchasing = true
        purchaseError = nil
        
        do {
            try await subscriptionManager.restorePurchases()
            isShowingPremiumView = false
        } catch {
            purchaseError = error.localizedDescription
        }
        
        isPurchasing = false
    }
    
    // MARK: - Premium Features Check
    func canAccessWeightTracking() -> Bool {
        return subscriptionManager.canAccessWeightTracking()
    }
    
    func canRemoveWatermark() -> Bool {
        return subscriptionManager.canRemoveWatermark()
    }
    
    func shouldShowAds() -> Bool {
        return subscriptionManager.shouldShowAds()
    }
    
    func canAccessAdvancedCharts() -> Bool {
        return subscriptionManager.canAccessAdvancedCharts()
    }
}