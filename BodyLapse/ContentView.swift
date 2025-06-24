//
//  ContentView.swift
//  BodyLapse
//
//  Created by Koji Okamoto on 2025/06/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var userSettings = UserSettingsManager()
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if !userSettings.settings.hasCompletedOnboarding {
                OnboardingView()
                    .environmentObject(userSettings)
            } else {
                TabView(selection: $selectedTab) {
                    CalendarView()
                        .tabItem {
                            Label("Calendar", systemImage: "calendar")
                        }
                        .tag(0)
                    
                    CompareView()
                        .tabItem {
                            Label("Compare", systemImage: "arrow.left.arrow.right")
                        }
                        .tag(1)
                    
                    PhotoCaptureView()
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
                            Label("Settings", systemImage: "gear")
                        }
                        .tag(4)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
