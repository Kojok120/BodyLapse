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
        // Initialize CategoryStorageService first
        _ = CategoryStorageService.shared
        
        // Perform data migration if needed
        DataMigrationService.shared.performMigrationIfNeeded()
        
        // Initialize PhotoStorageService on app launch
        PhotoStorageService.shared.initialize()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(languageManager)
                .tint(.bodyLapseTurquoise)
                .task {
                    // App launched - initializing StoreKit...
                    // Initialize StoreKit and subscription status on app launch
                    await subscriptionManager.loadProducts()
                    // Products loaded - refreshing subscription status...
                    await subscriptionManager.refreshSubscriptionStatus()
                    // Subscription status refreshed
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToCamera"))) { _ in
                    // Handle navigation to camera when notification is tapped
                    // This will be handled by ContentView
                }
        }
    }
}
