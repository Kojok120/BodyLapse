import Foundation
import UserNotifications
import UIKit

class NotificationService: NSObject {
    static let shared = NotificationService()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let reminderIdentifier = "daily-photo-reminder"
    
    private override init() {
        super.init()
        notificationCenter.delegate = self
    }
    
    // MARK: - Permission Management
    
    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Notification permission error: \(error)")
                    completion(false)
                } else {
                    completion(granted)
                }
            }
        }
    }
    
    func checkNotificationPermission(completion: @escaping (Bool) -> Void) {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }
    
    // MARK: - Reminder Scheduling
    
    func setupDailyPhotoCheck() {
        // Cancel any existing reminders
        cancelDailyReminder()
        
        // Check permission status first
        checkNotificationPermission { [weak self] authorized in
            guard authorized else { return }
            self?.scheduleDailyCheck()
        }
    }
    
    private func scheduleDailyCheck() {
        // Schedule a daily check at 19:00
        var dateComponents = DateComponents()
        dateComponents.hour = 19
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // Create a special identifier for the check
        let checkIdentifier = "daily-photo-check"
        
        // Use a minimal notification that will trigger our check
        let content = UNMutableNotificationContent()
        content.title = "" // Empty title to trigger check without showing
        content.userInfo = ["isPhotoCheck": true]
        
        let request = UNNotificationRequest(
            identifier: checkIdentifier,
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling daily check: \(error)")
            } else {
                print("Daily photo check scheduled for 19:00")
            }
        }
    }
    
    func checkAndSendPhotoReminder() {
        // Check if any photo was taken today across all categories
        let hasPhotoToday = PhotoStorageService.shared.hasAnyPhotoForToday()
        
        guard !hasPhotoToday else {
            print("Photo already taken today, skipping reminder")
            return
        }
        
        // Send reminder notification
        let content = UNMutableNotificationContent()
        content.title = "notification.no_photo_title".localized
        content.body = "notification.no_photo_body".localized
        content.sound = .default
        content.badge = 1
        content.userInfo = ["openCamera": true]
        
        // Send immediately
        let request = UNNotificationRequest(
            identifier: reminderIdentifier,
            content: content,
            trigger: nil // nil trigger means send immediately
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error sending photo reminder: \(error)")
            } else {
                print("Photo reminder sent")
            }
        }
    }
    
    func cancelDailyReminder() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [reminderIdentifier])
    }
    
    // MARK: - Badge Management
    
    func clearBadge() {
        Task {
            do {
                try await UNUserNotificationCenter.current().setBadgeCount(0)
            } catch {
                print("Error clearing badge count: \(error)")
            }
        }
    }
    
    // MARK: - Delivered Notifications
    
    func clearDeliveredNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Check if this is a photo check notification
        if let isPhotoCheck = notification.request.content.userInfo["isPhotoCheck"] as? Bool, isPhotoCheck {
            // Don't show the check notification, just perform the check
            checkAndSendPhotoReminder()
            completionHandler([])
        } else {
            // Show other notifications normally
            completionHandler([.banner, .list, .sound, .badge])
        }
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Clear badge when notification is tapped
        clearBadge()
        
        // Check if this is a photo reminder or has openCamera flag
        if response.notification.request.identifier == reminderIdentifier ||
           (response.notification.request.content.userInfo["openCamera"] as? Bool == true) {
            // Post notification to navigate to camera tab with camera launch
            NotificationCenter.default.post(
                name: Notification.Name("NavigateToCameraAndLaunch"),
                object: nil
            )
        }
        
        completionHandler()
    }
}