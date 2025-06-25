import SwiftUI
import GoogleMobileAds
import UIKit

struct BannerAdView: UIViewRepresentable {
    @StateObject private var premiumViewModel = PremiumViewModel()
    
    func makeUIView(context: Context) -> GADBannerView {
        let bannerView = GADBannerView()
        bannerView.adUnitID = AdMobService.shared.bannerAdUnitID
        bannerView.rootViewController = getRootViewController()
        bannerView.load(GADRequest())
        return bannerView
    }
    
    func updateUIView(_ uiView: GADBannerView, context: Context) {
        if premiumViewModel.isPremium {
            uiView.isHidden = true
        } else {
            uiView.isHidden = false
        }
    }
    
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        return window.rootViewController
    }
}

struct BannerAdModifier: ViewModifier {
    @StateObject private var premiumViewModel = PremiumViewModel()
    
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            content
            
            if !premiumViewModel.isPremium {
                BannerAdView()
                    .frame(height: 50)
                    .background(Color.gray.opacity(0.1))
            }
        }
    }
}

extension View {
    func withBannerAd() -> some View {
        modifier(BannerAdModifier())
    }
}