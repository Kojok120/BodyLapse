//
//  ContentView.swift
//  BodyLapse
//
//  Created by Koji Okamoto on 2025/06/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var userSettings = UserSettingsManager.shared
    
    var body: some View {
        Group {
            if !userSettings.settings.hasCompletedOnboarding {
                OnboardingView()
                    .environmentObject(userSettings)
            } else {
                MainTabView()
            }
        }
    }
}

#Preview {
    ContentView()
}
