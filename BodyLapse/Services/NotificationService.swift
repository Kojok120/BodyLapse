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
    
    func scheduleOrUpdateDailyReminder(at time: Date, enabled: Bool) {
        // Cancel existing reminder first
        cancelDailyReminder()
        
        guard enabled else { return }
        
        // Extract hour and minute components
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        
        guard let hour = components.hour, let minute = components.minute else { return }
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Time for your daily photo!"
        content.body = "Capture today's progress photo to track your transformation journey."
        content.sound = .default
        content.badge = 1
        
        // Create daily trigger
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: reminderIdentifier,
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("Daily reminder scheduled for \(hour):\(String(format: "%02d", minute))")
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
        // Show notification even when app is in foreground
        completionHandler([.banner, .list, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Clear badge when notification is tapped
        clearBadge()
        
        // Post notification to navigate to camera tab
        if response.notification.request.identifier == reminderIdentifier {
            NotificationCenter.default.post(
                name: Notification.Name("NavigateToCamera"),
                object: nil
            )
        }
        
        completionHandler()
    }
}