import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        
        // Initialize notification service
        _ = NotificationService.shared
        
        // 広告 SDK は、広告の同意 (EEA・英国など) を確かめてから AdConsentService が起動する

        // Clear badge on app launch
        Task {
            do {
                try await UNUserNotificationCenter.current().setBadgeCount(0)
            } catch {
                // Error clearing badge count
            }
        }
        
        // Notification setup is now handled in BodyLapseApp init
        
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
        
        // Reschedule notifications when app becomes active
        NotificationService.shared.rescheduleNotificationsIfNeeded()
    }
    
    // Force portrait orientation
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}