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

    var isPro: Bool {
        subscriptionManager.isPro
    }

    var tier: SubscriptionTier {
        subscriptionManager.tier
    }

    var standardProduct: Product? {
        products.first { $0.id == StoreProducts.premiumMonthly }
    }

    var proMonthlyProduct: Product? {
        products.first { $0.id == StoreProducts.proMonthly }
    }

    var proYearlyProduct: Product? {
        products.first { $0.id == StoreProducts.proYearly }
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
        // プロダクトを読み込み中...
        await subscriptionManager.loadProducts()
        // プロダクト読み込み完了
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
    
    // MARK: - プレミアム機能チェック
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