import SwiftUI
import StoreKit

@MainActor
class PremiumViewModel: ObservableObject {
    @Published var isShowingPremiumView = false
    @Published var isPurchasing = false
    @Published var purchaseError: String?
    
    private let storeManager = StoreManager.shared
    
    var products: [Product] {
        storeManager.products
    }
    
    var isPremium: Bool {
        storeManager.isPremium
    }
    
    var isLoadingProducts: Bool {
        storeManager.isLoadingProducts
    }
    
    func loadProducts() async {
        await storeManager.loadProducts()
    }
    
    func purchase(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil
        
        do {
            try await storeManager.purchase(product)
            isShowingPremiumView = false
        } catch {
            purchaseError = error.localizedDescription
        }
        
        isPurchasing = false
    }
    
    func restorePurchases() async {
        isPurchasing = true
        await storeManager.restorePurchases()
        isPurchasing = false
        
        if isPremium {
            isShowingPremiumView = false
        } else {
            purchaseError = "No purchases to restore"
        }
    }
    
    // MARK: - Premium Features Check
    func canAccessWeightTracking() -> Bool {
        return isPremium
    }
    
    func canRemoveWatermark() -> Bool {
        return isPremium
    }
    
    func shouldShowAds() -> Bool {
        return !isPremium
    }
}