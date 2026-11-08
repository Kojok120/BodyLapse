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
    @StateObject private var subscriptionManager = SubscriptionManagerService.shared
    @StateObject private var languageManager = LanguageManager.shared
    
    init() {
        // アプリスイッチャー用の目隠しと、バックグラウンド時のロック
        MainActor.assumeIsolated {
            PrivacyShieldController.shared.start()
        }

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

            // クラウド自動バックアップの通知購読を開始（実行はPro・設定ON等の条件付き）
            CloudBackupService.shared.activate()
        }
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
            // 言語を切り替えたら、画面の根元を差し替えずに階層ごと作り直す
            ContentView()
                .id(languageManager.uiRefreshID)
                .environmentObject(languageManager)
                .tint(.bodyLapseTurquoise)
                .task {
                    // 起動時に商品とサブスクの状態を読み込む
                    await subscriptionManager.loadProducts()
                    await subscriptionManager.refreshSubscriptionStatus()
                }
        }
    }
}

// Privacy screen view
struct PrivacyScreenView: View {
    var body: some View {
        ZStack {
            // Gradient background to match launch screen
            LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.686, blue: 0.8),     // Turquoise
                    Color(red: 0.988, green: 0.988, blue: 0.514)  // Yellow-Green
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Center logo container
            ZStack {
                // White semi-transparent circle background
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 150, height: 150)
                
                // Logo image
                Image("LaunchIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
            }
        }
    }
}
