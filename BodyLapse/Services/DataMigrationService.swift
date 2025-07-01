//
//  DataMigrationService.swift
//  BodyLapse
//
//  Created by Anthropic on 2025/01/01.
//

import Foundation

class DataMigrationService {
    static let shared = DataMigrationService()
    
    private let migrationVersionKey = "BodyLapseMigrationVersion"
    private let currentMigrationVersion = 1
    
    private init() {}
    
    func performMigrationIfNeeded() {
        let lastMigrationVersion = UserDefaults.standard.integer(forKey: migrationVersionKey)
        
        if lastMigrationVersion < currentMigrationVersion {
            print("Starting data migration from version \(lastMigrationVersion) to \(currentMigrationVersion)")
            
            if lastMigrationVersion < 1 {
                performMigrationToVersion1()
            }
            
            UserDefaults.standard.set(currentMigrationVersion, forKey: migrationVersionKey)
            print("Migration completed successfully")
        }
    }
    
    private func performMigrationToVersion1() {
        print("Performing migration to version 1: Multiple categories support")
        
        // 1. Ensure default category exists
        let categories = CategoryStorageService.shared.loadCategories()
        if categories.isEmpty {
            _ = CategoryStorageService.shared.addCategory(PhotoCategory.defaultCategory)
        }
        
        // 2. Migrate existing guideline to default category
        migrateExistingGuideline()
        
        // 3. Photo file migration is handled by PhotoStorageService.migratePhotosToCategory()
        // which is called during initialization
        
        print("Migration to version 1 completed")
    }
    
    private func migrateExistingGuideline() {
        // Check if there's an existing guideline in old format
        let oldGuidelineKey = "BodyLapseGuideline"
        
        if let guidelineData = UserDefaults.standard.data(forKey: oldGuidelineKey),
           let guideline = try? JSONDecoder().decode(BodyGuideline.self, from: guidelineData) {
            
            print("Found existing guideline, migrating to default category")
            
            // Save guideline to default category
            CategoryStorageService.shared.saveGuideline(
                for: PhotoCategory.defaultCategory.id,
                guideline: guideline
            )
            
            // Remove old guideline key
            UserDefaults.standard.removeObject(forKey: oldGuidelineKey)
            
            print("Guideline migration completed")
        }
    }
    
    func resetMigrationStatus() {
        // For debugging purposes
        UserDefaults.standard.removeObject(forKey: migrationVersionKey)
        print("Migration status reset")
    }
}