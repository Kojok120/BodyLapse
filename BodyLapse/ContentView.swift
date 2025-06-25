//
//  ContentView.swift
//  BodyLapse
//
//  Created by Koji Okamoto on 2025/06/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var userSettings = UserSettingsManager.shared
    @StateObject private var authService = AuthenticationService.shared
    @State private var hasAppeared = false
    
    var body: some View {
        Group {
            if !authService.isAuthenticated && authService.isAuthenticationEnabled && hasAppeared {
                AuthenticationView {
                    // Authentication successful
                }
            } else if !userSettings.settings.hasCompletedOnboarding {
                OnboardingView()
                    .environmentObject(userSettings)
            } else {
                MainTabView()
            }
        }
        .onAppear {
            // Small delay to prevent flashing of content before auth screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hasAppeared = true
            }
        }
    }
}

#Preview {
    ContentView()
}
