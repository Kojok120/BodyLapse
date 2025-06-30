//
//  BodyLapseApp.swift
//  BodyLapse
//
//  Created by Koji Okamoto on 2025/06/24.
//

import SwiftUI

@main
struct BodyLapseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var subscriptionManager = SubscriptionManagerService.shared
    @StateObject private var languageManager = LanguageManager.shared
    
    init() {
        // Initialize PhotoStorageService on app launch
        PhotoStorageService.shared.initialize()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(languageManager)
                .tint(.bodyLapseTurquoise)
                .task {
                    print("[BodyLapseApp] App launched - initializing StoreKit...")
                    // Initialize StoreKit and subscription status on app launch
                    await subscriptionManager.loadProducts()
                    print("[BodyLapseApp] Products loaded - refreshing subscription status...")
                    await subscriptionManager.refreshSubscriptionStatus()
                    print("[BodyLapseApp] Subscription status refreshed - isPremium: \(subscriptionManager.isPremium)")
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToCamera"))) { _ in
                    // Handle navigation to camera when notification is tapped
                    // This will be handled by ContentView
                }
        }
    }
}
