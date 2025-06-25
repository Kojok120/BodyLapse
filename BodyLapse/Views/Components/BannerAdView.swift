import SwiftUI
import GoogleMobileAds
import UIKit

struct BannerAdView: UIViewRepresentable {
    let isPremium: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> BannerView {
        print("[BannerAd] Creating banner view")
        print("[BannerAd] isPremium: \(isPremium)")
        
        let bannerView = BannerView()
        bannerView.adUnitID = AdMobService.shared.bannerAdUnitID
        bannerView.rootViewController = getRootViewController()
        
        // Use standard banner size (320x50)
        bannerView.adSize = AdSizeBanner
        
        // Hide immediately if premium
        if isPremium {
            bannerView.isHidden = true
        } else {
            print("[BannerAd] Loading banner with adUnitID: \(AdMobService.shared.bannerAdUnitID)")
            print("[BannerAd] Root view controller: \(bannerView.rootViewController != nil)")
            
            bannerView.delegate = context.coordinator
            
            let request = Request()
            bannerView.load(request)
        }
        
        return bannerView
    }
    
    func updateUIView(_ uiView: BannerView, context: Context) {
        print("[BannerAd] Update - isPremium: \(isPremium)")
        if isPremium {
            uiView.isHidden = true
        } else {
            uiView.isHidden = false
            // Reload ad if needed
            if uiView.responseInfo == nil {
                print("[BannerAd] Reloading ad")
                uiView.load(Request())
            }
        }
    }
    
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        return window.rootViewController
    }
    
    class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("[BannerAd] Banner ad loaded successfully")
        }
        
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("[BannerAd] Failed to load banner ad: \(error.localizedDescription)")
        }
        
        func bannerViewWillPresentScreen(_ bannerView: BannerView) {
            print("[BannerAd] Banner ad will present screen")
        }
    }
}

struct BannerAdModifier: ViewModifier {
    @StateObject private var userSettings = UserSettingsManager.shared
    
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            content
            
            if !userSettings.settings.isPremium {
                BannerAdView(isPremium: userSettings.settings.isPremium)
                    .frame(height: 50)
                    .background(Color(UIColor.systemBackground))
                    .onAppear {
                        print("[BannerAdModifier] Banner should appear - isPremium: \(userSettings.settings.isPremium)")
                    }
            } else {
                let _ = print("[BannerAdModifier] Banner hidden - user is premium")
            }
        }
        .onAppear {
            print("[BannerAdModifier] View appeared - isPremium: \(userSettings.settings.isPremium)")
        }
    }
}

extension View {
    func withBannerAd() -> some View {
        modifier(BannerAdModifier())
    }
}