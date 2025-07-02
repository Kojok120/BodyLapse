import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var videoToPlay: UUID?
    @State private var shouldLaunchCamera = false
    @StateObject private var userSettings = UserSettingsManager.shared
    
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
    }
}