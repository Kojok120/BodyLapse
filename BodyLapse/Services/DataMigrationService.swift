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
    private let currentMigrationVersion = 2
    
    private init() {}
    
    func performMigrationIfNeeded() {
        let lastMigrationVersion = UserDefaults.standard.integer(forKey: migrationVersionKey)
        
        if lastMigrationVersion < currentMigrationVersion {
            print("Starting data migration from version \(lastMigrationVersion) to \(currentMigrationVersion)")
            
            if lastMigrationVersion < 1 {
                performMigrationToVersion1()
            }
            
            if lastMigrationVersion < 2 {
                performMigrationToVersion2()
            }
            
            UserDefaults.standard.set(currentMigrationVersion, forKey: migrationVersionKey)
            print("Migration completed successfully")
        }
    }
    
    private func performMigrationToVersion1() {
        print("Performing migration to version 1: Multiple categories support")
        
        // 1. デフォルトカテゴリが存在することを確認
        let categories = CategoryStorageService.shared.loadCategories()
        if categories.isEmpty {
            _ = CategoryStorageService.shared.addCategory(PhotoCategory.defaultCategory)
        }
        
        // 2. 既存のガイドラインをデフォルトカテゴリに移行
        migrateExistingGuideline()
        
        // 3. 写真ファイルの移行はPhotoStorageService.migratePhotosToCategory()が処理
        // 初期化時に呼び出される
        
        print("Migration to version 1 completed")
    }
    
    private func performMigrationToVersion2() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        Self.removeLegacyDebugMask(in: documentsDirectory)
    }
    
    /// 旧版の輪郭検出が Documents に書き出していた人物シルエットの二値マスク。読む箇所はない
    static let legacyDebugMaskFileName = "opencv_binary_mask_from_uiimage.png"
    
    /// 旧版が残した二値マスクを消す。無ければ何もしない (何度呼んでもよい)
    static func removeLegacyDebugMask(in documentsDirectory: URL, fileManager: FileManager = .default) {
        let url = documentsDirectory.appendingPathComponent(legacyDebugMaskFileName)
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            print("[Migration] Failed to remove legacy debug mask: \(error)")
        }
    }
    
    private func migrateExistingGuideline() {
        // 旧フォーマットの既存ガイドラインがあるか確認
        let oldGuidelineKey = "BodyLapseGuideline"
        
        if let guidelineData = UserDefaults.standard.data(forKey: oldGuidelineKey),
           let guideline = try? JSONDecoder().decode(BodyGuideline.self, from: guidelineData) {
            
            print("Found existing guideline, migrating to default category")
            
            // ガイドラインをデフォルトカテゴリに保存
            CategoryStorageService.shared.saveGuideline(
                for: PhotoCategory.defaultCategory.id,
                guideline: guideline
            )
            
            // 旧ガイドラインキーを削除
            UserDefaults.standard.removeObject(forKey: oldGuidelineKey)
            
            print("Guideline migration completed")
        }
    }
}