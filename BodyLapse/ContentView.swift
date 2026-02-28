//
//  ContentView.swift
//  BodyLapse
//
//  Created by Koji Okamoto on 2025/06/24.
//

import SwiftUI

struct ContentView: View {
    enum RootDestination: Equatable {
        case onboarding
        case authentication
        case main
    }

    @StateObject private var userSettings = UserSettingsManager.shared
    @StateObject private var authService = AuthenticationService.shared
    
    static func destination(
        hasCompletedOnboarding: Bool,
        isAuthenticationEnabled: Bool,
        isAuthenticated: Bool
    ) -> RootDestination {
        if !hasCompletedOnboarding {
            return .onboarding
        }
        if isAuthenticationEnabled && !isAuthenticated {
            return .authentication
        }
        return .main
    }

    var body: some View {
        Group {
            switch Self.destination(
                hasCompletedOnboarding: userSettings.settings.hasCompletedOnboarding,
                isAuthenticationEnabled: authService.isAuthenticationEnabled,
                isAuthenticated: authService.isAuthenticated
            ) {
            case .onboarding:
                // Always show onboarding first if not completed
                OnboardingView()
                    .environmentObject(userSettings)
            case .authentication:
                // Only show authentication after onboarding is complete
                AuthenticationView {
                    // Authentication successful
                }
            case .main:
                MainTabView()
            }
        }
    }
}

#Preview {
    ContentView()
}
