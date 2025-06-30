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
        return "ca-app-pub-2130434444191865/5430877300"
        #endif
    }
    
    var interstitialAdUnitID: String {
        #if DEBUG
        return testInterstitialAdUnitID
        #else
        return "ca-app-pub-2130434444191865/8365814795"
        #endif
    }
    
    private var interstitialAd: InterstitialAd?
    private var isLoadingInterstitial = false
    private var interstitialCompletion: (() -> Void)?
    
    private override init() {
        super.init()
    }
    
    // Public method to check ad status
    func checkAdStatus() {
        // Ad status check removed for production
    }
    
    func initializeAdMob() {
        Task {
            await MobileAds.shared.start()
            // SDK initialized
            
            // Load interstitial ad immediately after initialization
            await MainActor.run {
                self.loadInterstitialAd()
            }
        }
    }
    
    func loadInterstitialAd() {
        guard !isLoadingInterstitial else { 
            // Already loading interstitial ad, skipping
            return 
        }
        
        // Starting to load interstitial ad
        
        isLoadingInterstitial = true
        let request = Request()
        
        InterstitialAd.load(with: interstitialAdUnitID,
                               request: request) { [weak self] ad, error in
            self?.isLoadingInterstitial = false
            
            if let error = error {
                // Failed to load interstitial ad
                return
            }
            
            self?.interstitialAd = ad
            self?.interstitialAd?.fullScreenContentDelegate = self
            // Interstitial ad loaded successfully
        }
    }
    
    func showInterstitialAd(from viewController: UIViewController, completion: (() -> Void)? = nil) {
        // Attempting to show interstitial ad
        
        if let ad = interstitialAd {
            // Presenting interstitial ad
            interstitialCompletion = completion
            
            // Ensure we're on the main thread
            DispatchQueue.main.async {
                ad.present(from: viewController)
                // Ad presentation called successfully
            }
        } else {
            // Interstitial ad not ready
            if !isLoadingInterstitial {
                // Loading new interstitial ad
                loadInterstitialAd()
            }
            completion?()
        }
    }
}

extension AdMobService: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        // Interstitial ad dismissed
        interstitialCompletion?()
        interstitialCompletion = nil
        loadInterstitialAd()
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        // Failed to present interstitial ad
        interstitialCompletion?()
        interstitialCompletion = nil
        loadInterstitialAd()
    }
    
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        // Interstitial ad will present
    }
}