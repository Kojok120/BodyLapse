import Foundation
import UIKit
import GoogleMobileAds

class AdMobService: NSObject {
    static let shared = AdMobService()
    
    private let testBannerAdUnitID = "ca-app-pub-3940256099942544/2934735716"
    private let testInterstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
    
    var bannerAdUnitID: String {
        #if DEBUG
        return testBannerAdUnitID
        #else
        return "YOUR_PRODUCTION_BANNER_AD_UNIT_ID"
        #endif
    }
    
    var interstitialAdUnitID: String {
        #if DEBUG
        return testInterstitialAdUnitID
        #else
        return "YOUR_PRODUCTION_INTERSTITIAL_AD_UNIT_ID"
        #endif
    }
    
    private var interstitialAd: GADInterstitialAd?
    private var isLoadingInterstitial = false
    
    private override init() {
        super.init()
    }
    
    func initializeAdMob() {
        GADMobileAds.sharedInstance().start { _ in
            print("AdMob SDK initialized")
            self.loadInterstitialAd()
        }
    }
    
    func loadInterstitialAd() {
        guard !isLoadingInterstitial else { return }
        
        isLoadingInterstitial = true
        let request = GADRequest()
        
        GADInterstitialAd.load(withAdUnitID: interstitialAdUnitID,
                               request: request) { [weak self] ad, error in
            self?.isLoadingInterstitial = false
            
            if let error = error {
                print("Failed to load interstitial ad: \(error.localizedDescription)")
                return
            }
            
            self?.interstitialAd = ad
            self?.interstitialAd?.fullScreenContentDelegate = self
            print("Interstitial ad loaded")
        }
    }
    
    func showInterstitialAd(from viewController: UIViewController, completion: (() -> Void)? = nil) {
        if let ad = interstitialAd {
            ad.present(fromRootViewController: viewController)
            completion?()
        } else {
            print("Interstitial ad not ready")
            completion?()
            loadInterstitialAd()
        }
    }
}

extension AdMobService: GADFullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("Interstitial ad dismissed")
        loadInterstitialAd()
    }
    
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Failed to present interstitial ad: \(error.localizedDescription)")
        loadInterstitialAd()
    }
}