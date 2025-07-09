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
            if !userSettings.settings.hasCompletedOnboarding {
                // Always show onboarding first if not completed
                OnboardingView()
                    .environmentObject(userSettings)
            } else if !authService.isAuthenticated && authService.isAuthenticationEnabled && hasAppeared {
                // Only show authentication after onboarding is complete
                AuthenticationView {
                    // Authentication successful
                }
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
