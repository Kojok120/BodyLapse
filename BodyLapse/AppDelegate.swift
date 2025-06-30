import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        
        // Initialize notification service
        _ = NotificationService.shared
        
        // Initialize AdMob with delay to ensure proper setup
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Initializing AdMob
            AdMobService.shared.initializeAdMob()
        }
        
        // Clear badge on app launch
        Task {
            do {
                try await UNUserNotificationCenter.current().setBadgeCount(0)
            } catch {
                // Error clearing badge count
            }
        }
        
        // Setup notification based on current settings
        let settings = UserSettingsManager.shared.settings
        if settings.reminderEnabled {
            NotificationService.shared.scheduleOrUpdateDailyReminder(
                at: settings.reminderTime,
                enabled: true
            )
        }
        
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Clear badge when app becomes active
        Task {
            do {
                try await UNUserNotificationCenter.current().setBadgeCount(0)
            } catch {
                // Error clearing badge count
            }
        }
        NotificationService.shared.clearDeliveredNotifications()
    }
    
    // Force portrait orientation
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}