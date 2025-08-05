import Foundation
import UserNotifications
import UIKit

class NotificationService: NSObject {
    static let shared = NotificationService()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let reminderIdentifier = "daily-photo-reminder"  // User-configured daily reminder
    private let missedPhotoIdentifier = "missed-photo-reminder"  // 21:00 automatic check
    
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
            // Schedule both types of reminders
            self?.scheduleDailyCheck()  // 21:00 check for missed photos
            self?.scheduleDailyReminder()  // User-configured daily reminder
        }
    }
    
    // Cancel today's 21:00 notification if photo was taken
    func cancelTodaysMissedPhotoNotification() {
        let calendar = Calendar.current
        let today = Date()
        
        // Find and cancel today's notification
        for dayOffset in 0..<7 {
            let identifier = "missed-photo-day-\(dayOffset)"
            
            notificationCenter.getPendingNotificationRequests { requests in
                for request in requests {
                    if request.identifier == identifier,
                       let scheduledDate = request.content.userInfo["scheduledDate"] as? Date,
                       calendar.isDate(scheduledDate, inSameDayAs: today) {
                        self.notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
                        print("Cancelled today's 21:00 notification")
                        break
                    }
                }
            }
        }
    }
    
    // Schedule user-configured daily reminder
    func scheduleDailyReminder() {
        // Cancel existing user reminder
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
        
        // Check permission status first
        checkNotificationPermission { [weak self] authorized in
            guard authorized else { return }
            
            Task { @MainActor in
                // Get user settings
                let settings = UserSettingsManager.shared.settings
                
                // Only schedule if the reminder is enabled
                guard settings.isReminderEnabled else {
                    print("Daily reminder is disabled. Skipping scheduling.")
                    return
                }
                
                // Schedule daily reminder at user-configured time
                var dateComponents = DateComponents()
                dateComponents.hour = settings.reminderHour
                dateComponents.minute = settings.reminderMinute
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                
                // Create reminder content
                let content = UNMutableNotificationContent()
                content.title = "notification.daily_reminder_title".localized
                content.body = "notification.daily_reminder_body".localized
                content.sound = .default
                content.badge = 1
                content.userInfo = ["openCamera": true]
                
                let request = UNNotificationRequest(
                    identifier: self?.reminderIdentifier ?? "daily-photo-reminder",
                    content: content,
                    trigger: trigger
                )
                
                self?.notificationCenter.add(request) { error in
                    if let error = error {
                        print("Error scheduling daily reminder: \(error)")
                    } else {
                        print("Daily reminder scheduled for \(settings.reminderHour):\(String(format: "%02d", settings.reminderMinute))")
                    }
                }
            }
        }
    }
    
    private func scheduleDailyCheck() {
        // Schedule notifications for the next 7 days at 21:00
        let calendar = Calendar.current
        let now = Date()
        
        // Cancel all existing missed photo notifications
        var identifiersToRemove = [String]()
        for day in 0..<7 {
            identifiersToRemove.append("missed-photo-day-\(day)")
        }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        
        // Schedule notifications for the next 7 days
        for dayOffset in 0..<7 {
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
            dateComponents.hour = 21
            dateComponents.minute = 0
            
            // Skip if the time has already passed today
            if let notificationDate = calendar.date(from: dateComponents), notificationDate <= now {
                continue
            }
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
            let content = UNMutableNotificationContent()
            content.title = "notification.no_photo_title".localized
            content.body = "notification.no_photo_body".localized
            content.sound = .default
            content.badge = 1
            content.userInfo = ["openCamera": true, "scheduledDate": targetDate]
            
            let request = UNNotificationRequest(
                identifier: "missed-photo-day-\(dayOffset)",
                content: content,
                trigger: trigger
            )
            
            notificationCenter.add(request) { error in
                if let error = error {
                    print("Error scheduling notification for day \(dayOffset): \(error)")
                } else {
                    print("Notification scheduled for day \(dayOffset) at 21:00")
                }
            }
        }
        
        print("Daily photo check notifications scheduled for the next 7 days")
    }
    
    // Reschedule notifications when app becomes active
    func rescheduleNotificationsIfNeeded() {
        // Check if any photo was taken today
        let hasPhotoToday = PhotoStorageService.shared.hasAnyPhotoForToday()
        
        if hasPhotoToday {
            // Cancel today's notification if photo was taken
            cancelTodaysMissedPhotoNotification()
        }
        
        // Reschedule notifications for next 7 days
        scheduleDailyCheck()
    }
    
    func cancelDailyReminder() {
        var identifiersToRemove = [reminderIdentifier, missedPhotoIdentifier]
        // Add all missed photo day identifiers
        for day in 0..<7 {
            identifiersToRemove.append("missed-photo-day-\(day)")
        }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [reminderIdentifier, missedPhotoIdentifier])
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
        // Show all notifications normally
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
        
        // Check if this is any type of photo reminder or has openCamera flag
        if response.notification.request.identifier == reminderIdentifier ||
           response.notification.request.identifier == missedPhotoIdentifier ||
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