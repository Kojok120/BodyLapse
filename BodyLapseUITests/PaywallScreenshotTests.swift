import XCTest

/// サブスク審査用スクリーンショットの取得専用テスト。
/// オンボーディング完了状態を launch arguments で注入し、設定→ペイウォールを開いて撮影する。
/// 通常の CI では実行不要（審査素材の再生成時のみ使う）。
final class PaywallScreenshotTests: XCTestCase {

    @MainActor
    func testCapturePaywallScreenshot() throws {
        let app = XCUIApplication()

        // UserSettings(Codable) と同じ形の JSON を UserDefaults の引数ドメイン経由で注入し、
        // オンボーディングをスキップする（old-style plist の <hex> リテラルは Data になる）。
        let settingsJSON = #"{"showBodyGuidelines":true,"weightUnit":"kg","healthKitEnabled":false,"hasCompletedOnboarding":true,"isAppLockEnabled":false,"appLockMethod":"Face ID \/ Touch ID","hasRatedApp":true,"showDateInVideo":true,"isReminderEnabled":false,"reminderHour":19,"reminderMinute":0,"appearanceMode":"light","faceBlurMethod":"strongBlur","debugAllowPastDatePhotos":false}"#
        let hex = Data(settingsJSON.utf8).map { String(format: "%02x", $0) }.joined()
        app.launchArguments = ["-BodyLapseUserSettings", "<\(hex)>"]

        // 通知許可などのシステムダイアログは自動で許可して先へ進む
        addUIInterruptionMonitor(withDescription: "System dialogs") { alert in
            for label in ["Allow", "OK", "許可"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }

        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 20), "Settings tab not found")
        settingsTab.tap()
        settingsTab.tap() // interruption monitor のトリガー兼、確実な選択

        // 「Remove Ads」行（ペイウォールを開く）までスクロールしてタップ。
        // 行のラベルはタイトル・説明・価格が連結されるため前方一致で探す。
        let upgradeRow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Remove Ads'")
        ).firstMatch
        var attempts = 0
        while !upgradeRow.isHittable && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(upgradeRow.waitForExistence(timeout: 5), "Remove Ads row not found")
        upgradeRow.tap()

        // ペイウォール表示と StoreKit 商品ロードを待つ
        sleep(8)

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "paywall"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
