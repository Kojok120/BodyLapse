//
//  BodyLapseApp.swift
//  BodyLapse
//
//  Created by Koji Okamoto on 2025/06/24.
//

import SwiftUI

@main
struct BodyLapseApp: App {
    @StateObject private var storeManager = StoreManager.shared
    
    init() {
        // Initialize PhotoStorageService on app launch
        PhotoStorageService.shared.initialize()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Initialize StoreKit on app launch
                    await storeManager.loadProducts()
                }
        }
    }
}
