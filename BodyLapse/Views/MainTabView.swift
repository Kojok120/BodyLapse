import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var userSettings = UserSettingsManager()
    
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
            
            GalleryView()
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
    }
}