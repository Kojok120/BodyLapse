import UIKit
import GoogleMobileAds
import UserMessagingPlatform

/// 広告の同意 (EEA・英国・スイスなど) を Google の UMP で取り、広告を出してよくなってから広告 SDK を起動する。
///
/// 同意が要らない地域では画面は出ず、そのまま広告 SDK を起動する。
/// 同意画面の中身は AdMob の管理画面の「プライバシーとメッセージ」で作ったものが出る。
@Observable
@MainActor
final class AdConsentService {
    static let shared = AdConsentService()

    /// 広告を読み込んでよいか。同意の状態が変わったらバナーが読み込み直せるよう公開する
    private(set) var canRequestAds = false
    /// 設定に「広告のプライバシー設定」を出すか (同意を取った地域でだけ必要)
    private(set) var isPrivacyOptionsRequired = false

    @ObservationIgnored private var isGathering = false
    @ObservationIgnored private var hasStartedMobileAds = false

    private init() {
        refreshState()
    }

    /// 起動時に 1 回呼ぶ。広告を出さない人 (有料プラン) には同意を求めない。
    func gatherConsentIfNeeded(isAdFree: Bool) async {
        guard !isAdFree, !isGathering else { return }
        isGathering = true
        defer { isGathering = false }

        // 前回までに取った同意で広告を出してよいなら、更新を待たずに起動しておく (Google の推奨する順序)
        startMobileAdsIfAllowed()

        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: Self.requestParameters())
            if let presenter = PresentingViewController.top() {
                try await ConsentForm.loadAndPresentIfRequired(from: presenter)
            }
        } catch {
            // 通信できないなどで更新に失敗しても、前回の同意のまま進める
            print("[AdConsent] Failed to gather consent: \(error.localizedDescription)")
        }

        refreshState()
        startMobileAdsIfAllowed()
    }

    /// 設定から、同意の内容を変える画面を出す
    func presentPrivacyOptions() async {
        guard let presenter = PresentingViewController.top() else { return }
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: presenter)
        } catch {
            print("[AdConsent] Failed to present privacy options: \(error.localizedDescription)")
        }
        refreshState()
        startMobileAdsIfAllowed()
    }

    private func refreshState() {
        canRequestAds = ConsentInformation.shared.canRequestAds
        isPrivacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    private func startMobileAdsIfAllowed() {
        refreshState()
        guard canRequestAds, !hasStartedMobileAds else { return }
        hasStartedMobileAds = true
        AdMobService.shared.initializeAdMob()
    }

    private static func requestParameters() -> RequestParameters {
        let parameters = RequestParameters()
        #if DEBUG
        // シミュレータで同意画面を確かめるとき: 起動引数に -UMPDebugGeographyEEA を付ける
        if ProcessInfo.processInfo.arguments.contains("-UMPDebugGeographyEEA") {
            let debugSettings = DebugSettings()
            debugSettings.geography = .EEA
            parameters.debugSettings = debugSettings
        }
        if ProcessInfo.processInfo.arguments.contains("-UMPResetConsent") {
            ConsentInformation.shared.reset()
        }
        #endif
        return parameters
    }
}
