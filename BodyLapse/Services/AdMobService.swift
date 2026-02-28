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
    
    // 広告ステータスを確認する公開メソッド
    func checkAdStatus() {
        // 本番環境では広告ステータスチェックを削除
    }
    
    func initializeAdMob() {
        Task {
            await MobileAds.shared.start()
            // SDK初期化完了
            
            // 初期化直後にインタースティシャル広告を読み込み
            await MainActor.run {
                self.loadInterstitialAd()
            }
        }
    }
    
    func loadInterstitialAd() {
        guard !isLoadingInterstitial else { 
            // インタースティシャル広告は既に読み込み中、スキップ
            return 
        }
        
        // インタースティシャル広告の読み込みを開始
        
        isLoadingInterstitial = true
        let request = Request()
        
        InterstitialAd.load(with: interstitialAdUnitID,
                               request: request) { [weak self] ad, error in
            self?.isLoadingInterstitial = false
            
            if error != nil {
                // インタースティシャル広告の読み込みに失敗
                return
            }
            
            self?.interstitialAd = ad
            self?.interstitialAd?.fullScreenContentDelegate = self
            // インタースティシャル広告の読み込み成功
        }
    }
    
    func showInterstitialAd(from viewController: UIViewController, completion: (() -> Void)? = nil) {
        // インタースティシャル広告の表示を試行
        
        if let ad = interstitialAd {
            // インタースティシャル広告を表示
            interstitialCompletion = completion
            
            // メインスレッドで実行を保証
            DispatchQueue.main.async {
                ad.present(from: viewController)
                // 広告表示呼び出し成功
            }
        } else {
            // インタースティシャル広告が未準備
            if !isLoadingInterstitial {
                // 新しいインタースティシャル広告を読み込み
                loadInterstitialAd()
            }
            completion?()
        }
    }
}

extension AdMobService: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        // インタースティシャル広告が閉じられた
        interstitialCompletion?()
        interstitialCompletion = nil
        loadInterstitialAd()
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        // インタースティシャル広告の表示に失敗
        interstitialCompletion?()
        interstitialCompletion = nil
        loadInterstitialAd()
    }
    
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        // インタースティシャル広告が表示される
    }
}