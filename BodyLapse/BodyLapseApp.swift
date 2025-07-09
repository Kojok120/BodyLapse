//
//  BodyLapseApp.swift
//  BodyLapse
//
//  Created by Koji Okamoto on 2025/06/24.
//

import SwiftUI
import TipKit

@main
struct BodyLapseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var subscriptionManager = SubscriptionManagerService.shared
    @StateObject private var languageManager = LanguageManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowingPrivacyScreen = false
    
    init() {
        // Check if this is a fresh install and clear keychain if needed
        checkAndClearKeychainOnFreshInstall()
        
        // Initialize CategoryStorageService first
        _ = CategoryStorageService.shared
        
        // Perform data migration if needed
        DataMigrationService.shared.performMigrationIfNeeded()
        
        // Initialize PhotoStorageService on app launch
        PhotoStorageService.shared.initialize()
        
        // Set up daily photo reminder check
        NotificationService.shared.setupDailyPhotoCheck()
        
        // Initialize appearance manager to apply saved appearance mode
        Task { @MainActor in
            _ = AppearanceManager.shared
        }
        
        // Configure TipKit
        try? Tips.configure([
            .displayFrequency(.immediate),
            .datastoreLocation(.applicationDefault)
        ])
    }
    
    private func checkAndClearKeychainOnFreshInstall() {
        let hasLaunchedKey = "BodyLapseHasLaunchedBefore"
        let hasLaunched = UserDefaults.standard.bool(forKey: hasLaunchedKey)
        
        if !hasLaunched {
            // This is a fresh install, clear any existing keychain data
            AuthenticationService.shared.removePassword()
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(languageManager)
                    .tint(.bodyLapseTurquoise)
                
                // Privacy screen overlay
                if isShowingPrivacyScreen {
                    PrivacyScreenView()
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                switch newPhase {
                case .inactive:
                    // Show privacy screen when app becomes inactive (including app switcher)
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isShowingPrivacyScreen = true
                    }
                case .active:
                    // Hide privacy screen when app becomes active
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isShowingPrivacyScreen = false
                    }
                case .background:
                    // Keep privacy screen shown in background
                    isShowingPrivacyScreen = true
                @unknown default:
                    break
                }
            }
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

// Privacy screen view
struct PrivacyScreenView: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            
            Image("privacy-screen")
                .resizable()
                .scaledToFit()
                .padding(40)
        }
    }
}
