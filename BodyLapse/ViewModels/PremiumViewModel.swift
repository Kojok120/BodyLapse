import SwiftUI
import StoreKit

@MainActor
class PremiumViewModel: ObservableObject {
    @Published var isShowingPremiumView = false
    @Published var isPurchasing = false
    @Published var purchaseError: String?
    /// 無料体験を使える商品の ID (体験を使い切った人には出さない)
    @Published private(set) var freeTrialEligibleIDs: Set<String> = []
    
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
        await subscriptionManager.loadProducts()
        await refreshFreeTrialEligibility()
    }

    /// Pro の無料体験を使えるかを App Store に問い合わせる
    func refreshFreeTrialEligibility() async {
        var eligible = Set<String>()
        for product in [proYearlyProduct, proMonthlyProduct].compactMap({ $0 }) {
            guard let subscription = product.subscription,
                  subscription.introductoryOffer?.paymentMode == .freeTrial else { continue }
            if await subscription.isEligibleForIntroOffer {
                eligible.insert(product.id)
            }
        }
        freeTrialEligibleIDs = eligible
    }

    /// 「1週間無料」のような体験の表示。使えない商品は nil
    func freeTrialText(for product: Product) -> String? {
        guard freeTrialEligibleIDs.contains(product.id),
              let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        return FreeTrialText.text(value: offer.period.value * max(offer.periodCount, 1), unit: offer.period.unit)
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