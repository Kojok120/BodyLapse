import Foundation
import UserNotifications
import UIKit

class NotificationService: NSObject {
    static let shared = NotificationService()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let reminderIdentifier = "daily-photo-reminder"  // ユーザー設定の毎日リマインダー
    private let missedPhotoIdentifier = "missed-photo-reminder"  // 21:00の自動チェック
    
    private override init() {
        super.init()
        notificationCenter.delegate = self
    }
    
    // MARK: - 権限管理
    
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
    
    // MARK: - リマインダーのスケジューリング
    
    func setupDailyPhotoCheck() {
        // 既存のリマインダーをキャンセル
        cancelDailyReminder()
        
        // Check permission status first
        checkNotificationPermission { [weak self] authorized in
            guard authorized else { return }
            let hasPhotoToday = PhotoStorageService.shared.hasAnyPhotoForToday()
            // Schedule both types of reminders
            self?.scheduleDailyCheck(skipToday: hasPhotoToday)  // 21:00 check for missed photos
            self?.scheduleDailyReminder()  // User-configured daily reminder
        }
    }
    
    // 写真が撮影された場合、今日の21:00通知をキャンセル
    func cancelTodaysMissedPhotoNotification() {
        let calendar = Calendar.current
        let today = Date()
        
        // 今日の通知を検索してキャンセル
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
    
    // ユーザー設定の毎日リマインダーをスケジュール
    func scheduleDailyReminder() {
        // 既存のユーザーリマインダーをキャンセル
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
        
        // 権限ステータスをまず確認
        checkNotificationPermission { [weak self] authorized in
            guard authorized else { return }
            
            Task { @MainActor in
                // ユーザー設定を取得
                let settings = UserSettingsManager.shared.settings
                
                // リマインダーが有効な場合のみスケジュール
                guard settings.isReminderEnabled else {
                    print("Daily reminder is disabled. Skipping scheduling.")
                    return
                }
                
                // ユーザー設定の時刻に毎日リマインダーをスケジュール
                var dateComponents = DateComponents()
                dateComponents.hour = settings.reminderHour
                dateComponents.minute = settings.reminderMinute
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                
                // リマインダーコンテンツを作成
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
    
    private func scheduleDailyCheck(skipToday: Bool = false) {
        // 次の7日間の21:00に通知をスケジュール
        let calendar = Calendar.current
        let now = Date()
        
        // 既存の未撮影通知を全てキャンセル
        var identifiersToRemove = [String]()
        for day in 0..<7 {
            identifiersToRemove.append("missed-photo-day-\(day)")
        }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        
        // 次の7日間の通知をスケジュール
        for dayOffset in 0..<7 {
            if skipToday && dayOffset == 0 {
                continue
            }

            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
            dateComponents.hour = 21
            dateComponents.minute = 0
            
            // 今日既に時刻が過ぎている場合はスキップ
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
    
    // アプリがアクティブになったときに通知を再スケジュール
    func rescheduleNotificationsIfNeeded() {
        // 今日写真が撮影されたか確認
        let hasPhotoToday = PhotoStorageService.shared.hasAnyPhotoForToday()

        // 次の7日間の通知を再スケジュール（今日撮影済みの場合は当日分を除外）
        scheduleDailyCheck(skipToday: hasPhotoToday)
    }
    
    func cancelDailyReminder() {
        var identifiersToRemove = [reminderIdentifier, missedPhotoIdentifier]
        // 全ての未撮影日識別子を追加
        for day in 0..<7 {
            identifiersToRemove.append("missed-photo-day-\(day)")
        }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [reminderIdentifier, missedPhotoIdentifier])
    }
    
    // MARK: - バッジ管理
    
    func clearBadge() {
        Task {
            do {
                try await UNUserNotificationCenter.current().setBadgeCount(0)
            } catch {
                print("Error clearing badge count: \(error)")
            }
        }
    }
    
    // MARK: - 配信済み通知
    
    func clearDeliveredNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
    }
}

// MARK: - UNUserNotificationCenterデリゲート

extension NotificationService: UNUserNotificationCenterDelegate {
    
    // アプリがフォアグラウンドのときの通知処理
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 全ての通知を通常通り表示
        completionHandler([.banner, .list, .sound, .badge])
    }
    
    // 通知タップ時の処理
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // 通知タップ時にバッジをクリア
        clearBadge()
        
        // 写真リマインダーまたはopenCameraフラグがあるか確認
        if response.notification.request.identifier == reminderIdentifier ||
           response.notification.request.identifier == missedPhotoIdentifier ||
           (response.notification.request.content.userInfo["openCamera"] as? Bool == true) {
            // カメラタブにナビゲートしてカメラを起動する通知を送信
            NotificationCenter.default.post(
                name: Notification.Name("NavigateToCameraAndLaunch"),
                object: nil
            )
        }
        
        completionHandler()
    }
}
