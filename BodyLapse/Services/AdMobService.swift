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
        print("[AdMob] === Ad Status Check ===")
        print("[AdMob] Interstitial ad loaded: \(interstitialAd != nil)")
        print("[AdMob] Is loading: \(isLoadingInterstitial)")
        print("[AdMob] Ad Unit ID: \(interstitialAdUnitID)")
        print("[AdMob] ======================")
    }
    
    func initializeAdMob() {
        Task {
            await MobileAds.shared.start()
            print("[AdMob] SDK initialized")
            
            // Load interstitial ad immediately after initialization
            await MainActor.run {
                self.loadInterstitialAd()
            }
        }
    }
    
    func loadInterstitialAd() {
        guard !isLoadingInterstitial else { 
            print("[AdMob] Already loading interstitial ad, skipping")
            return 
        }
        
        print("[AdMob] Starting to load interstitial ad")
        print("[AdMob] Ad Unit ID: \(interstitialAdUnitID)")
        
        isLoadingInterstitial = true
        let request = Request()
        
        InterstitialAd.load(with: interstitialAdUnitID,
                               request: request) { [weak self] ad, error in
            self?.isLoadingInterstitial = false
            
            if let error = error {
                print("[AdMob] Failed to load interstitial ad: \(error.localizedDescription)")
                print("[AdMob] Error domain: \(error._domain)")
                print("[AdMob] Error code: \(error._code)")
                return
            }
            
            self?.interstitialAd = ad
            self?.interstitialAd?.fullScreenContentDelegate = self
            print("[AdMob] Interstitial ad loaded successfully")
            print("[AdMob] Ad object: \(String(describing: ad))")
        }
    }
    
    func showInterstitialAd(from viewController: UIViewController, completion: (() -> Void)? = nil) {
        print("[AdMob] Attempting to show interstitial ad")
        print("[AdMob] Interstitial ad exists: \(interstitialAd != nil)")
        print("[AdMob] View controller: \(type(of: viewController))")
        print("[AdMob] Is loading: \(isLoadingInterstitial)")
        
        if let ad = interstitialAd {
            print("[AdMob] Presenting interstitial ad")
            interstitialCompletion = completion
            
            // Ensure we're on the main thread
            DispatchQueue.main.async {
                ad.present(from: viewController)
                print("[AdMob] Ad presentation called successfully")
            }
        } else {
            print("[AdMob] Interstitial ad not ready")
            if !isLoadingInterstitial {
                print("[AdMob] Loading new interstitial ad")
                loadInterstitialAd()
            }
            completion?()
        }
    }
}

extension AdMobService: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Interstitial ad dismissed")
        interstitialCompletion?()
        interstitialCompletion = nil
        loadInterstitialAd()
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[AdMob] Failed to present interstitial ad: \(error.localizedDescription)")
        print("[AdMob] Error: \(error)")
        interstitialCompletion?()
        interstitialCompletion = nil
        loadInterstitialAd()
    }
    
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Interstitial ad will present")
    }
}