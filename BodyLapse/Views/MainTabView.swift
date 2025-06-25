import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var videoToPlay: UUID?
    @StateObject private var userSettings = UserSettingsManager.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(0)
            
            ComparisonView()
                .tabItem {
                    Label("Compare", systemImage: "square.on.square")
                }
                .tag(1)
            
            CameraView()
                .tabItem {
                    Label("Photo", systemImage: "camera.fill")
                }
                .tag(2)
            
            GalleryView(videoToPlay: $videoToPlay)
                .tabItem {
                    Label("Gallery", systemImage: "photo.stack")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToCamera"))) { _ in
            selectedTab = 2 // Camera tab
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