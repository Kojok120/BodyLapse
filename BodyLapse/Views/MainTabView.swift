import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var videoToPlay: UUID?
    @State private var shouldLaunchCamera = false
    @StateObject private var userSettings = UserSettingsManager.shared
    @StateObject private var subscriptionManager = SubscriptionManagerService.shared
    @State private var hasPerformedInitialSync = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarView()
                .tabItem {
                    Label("tab.calendar".localized, systemImage: "calendar")
                }
                .tag(0)
            
            CompareView()
                .tabItem {
                    Label("tab.compare".localized, systemImage: "square.on.square")
                }
                .tag(1)
            
            CameraView(shouldLaunchCamera: $shouldLaunchCamera)
                .tabItem {
                    Label("tab.photo".localized, systemImage: "camera.fill")
                }
                .tag(2)
            
            GalleryView(videoToPlay: $videoToPlay)
                .tabItem {
                    Label("tab.gallery".localized, systemImage: "photo.stack")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label("tab.settings".localized, systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToCamera"))) { _ in
            selectedTab = 2 // Camera tab
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToCameraAndLaunch"))) { _ in
            selectedTab = 2 // Camera tab
            shouldLaunchCamera = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToGalleryAndPlayVideo"))) { notification in
            if let videoId = notification.userInfo?["videoId"] as? UUID {
                videoToPlay = videoId
                selectedTab = 3 // Gallery tab
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToCalendarToday"))) { _ in
            selectedTab = 0 // Calendar tab
        }
        .onAppear {
            performInitialHealthKitSync()
        }
    }
    
    private func performInitialHealthKitSync() {
        // Only sync if:
        // 1. We haven't performed initial sync yet
        // 2. User is premium
        // 3. HealthKit is enabled
        guard !hasPerformedInitialSync,
              subscriptionManager.isPremium,
              userSettings.settings.healthKitEnabled else {
            return
        }
        
        hasPerformedInitialSync = true
        
        // Check if HealthKit is authorized
        if HealthKitService.shared.isAuthorized() {
            // Perform sync in background
            Task {
                await MainActor.run {
                    HealthKitService.shared.syncHealthDataToApp { success, error in
                        if success {
                            print("HealthKit data synced on app launch")
                        } else if let error = error {
                            print("Failed to sync HealthKit data on launch: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
}