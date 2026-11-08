//
//  CategoryStorageService.swift
//  BodyLapse
//
//  Created by Anthropic on 2025/01/01.
//

import Foundation

class CategoryStorageService {
    static let shared = CategoryStorageService()
    
    private let categoriesFileName = "categories.json"
    
    private var documentsDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    private var categoriesDirectory: URL? {
        documentsDirectory?.appendingPathComponent("Categories")
    }
    
    private var categoriesFileURL: URL? {
        categoriesDirectory?.appendingPathComponent(categoriesFileName)
    }
    
    /// ディスクの categories.json をデコードしたもの。nil は「まだ読んでいない」、
    /// .some(nil) は「ファイルが無い・読めない」。body やフレームごとのループから何度も呼ばれるので、
    /// 保存したときだけ入れ替え、読むたびにディスクから JSON をデコードしない。
    /// 動画生成や取り込みはメインの外から読むので、ロックで守る
    private var cachedCategories: [PhotoCategory]??
    private let cacheLock = NSLock()

    private init() {
        createDirectoriesIfNeeded()
        initializeDefaultCategoryIfNeeded()
    }
    
    private func createDirectoriesIfNeeded() {
        guard let categoriesDir = categoriesDirectory else { return }
        
        if !FileManager.default.fileExists(atPath: categoriesDir.path) {
            try? FileManager.default.createDirectory(at: categoriesDir, withIntermediateDirectories: true)
        }
    }
    
    private func initializeDefaultCategoryIfNeeded() {
        let categories = loadCategories()
        if categories.isEmpty {
            let defaultCategories = [PhotoCategory.defaultCategory]
            saveCategories(defaultCategories)
        }
    }
    
    func loadCategories() -> [PhotoCategory] {
        guard let categories = storedCategories() else { return [] }
        return categories.filter { $0.isActive }.sorted { $0.order < $1.order }
    }
    
    func saveCategories(_ categories: [PhotoCategory]) {
        guard let url = categoriesFileURL else { return }
        
        cacheLock.lock()
        defer { cacheLock.unlock() }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(categories)
            try data.write(to: url, options: .atomic)
            cachedCategories = .some(categories)
        } catch {
            // 書けなかったときは、次に読むときディスクの中身を読み直す
            cachedCategories = nil
            print("Error saving categories: \(error)")
        }
    }

    /// 保存してあるカテゴリ (無効にしたものも含む)。ファイルが無い・読めないときは nil
    private func storedCategories() -> [PhotoCategory]? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cachedCategories {
            return cachedCategories
        }
        let loaded = readCategoriesFromDisk()
        cachedCategories = .some(loaded)
        return loaded
    }

    private func readCategoriesFromDisk() -> [PhotoCategory]? {
        guard let url = categoriesFileURL,
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let categories = try? JSONDecoder().decode([PhotoCategory].self, from: data) else {
            return nil
        }
        return categories
    }
    
    func addCategory(_ category: PhotoCategory) -> Bool {
        var categories = loadAllCategories()
        
        let customCategories = categories.filter { $0.isCustom && $0.isActive }
        if customCategories.count >= PhotoCategory.maxCustomCategories {
            return false
        }
        
        categories.append(category)
        saveCategories(categories)
        
        createCategoryDirectory(for: category)
        
        // カテゴリ変更の通知を送信
        NotificationCenter.default.post(name: Notification.Name("CategoriesUpdated"), object: nil)
        
        return true
    }
    
    func updateCategory(_ category: PhotoCategory) {
        var categories = loadAllCategories()
        
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
            saveCategories(categories)
        }
    }
    
    func deleteCategory(id: String) {
        var categories = loadAllCategories()
        
        if let index = categories.firstIndex(where: { $0.id == id && $0.isCustom }) {
            categories[index].isActive = false
            saveCategories(categories)
            
            // このカテゴリに関連する全写真を削除
            deletePhotosForCategory(id: id)
            
            // このカテゴリのガイドラインを削除
            removeGuideline(for: id)
            
            // カテゴリ変更の通知を送信
            NotificationCenter.default.post(name: Notification.Name("CategoriesUpdated"), object: nil)
        }
    }
    
    private func deletePhotosForCategory(id: String) {
        // ドキュメントディレクトリを取得
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        let categoryFolderPath = documentsPath.appendingPathComponent("Photos").appendingPathComponent(id)
        
        // カテゴリフォルダが存在する場合は削除
        if FileManager.default.fileExists(atPath: categoryFolderPath.path) {
            try? FileManager.default.removeItem(at: categoryFolderPath)
        }
    }
    
    func canAddMoreCategories() -> Bool {
        let categories = loadCategories()
        let customCategories = categories.filter { $0.isCustom }
        return customCategories.count < PhotoCategory.maxCustomCategories
    }
    
    func getCategoryById(_ id: String) -> PhotoCategory? {
        return loadCategories().first { $0.id == id }
    }
    
    func getActiveCategories() -> [PhotoCategory] {
        return loadCategories()
    }
    
    func getNextUncapturedCategory(for date: Date, currentCategoryId: String) -> PhotoCategory? {
        let availableCategories = getActiveCategories()
        
        // 現在のカテゴリのインデックスを検出
        guard let currentIndex = availableCategories.firstIndex(where: { $0.id == currentCategoryId }) else {
            return nil
        }
        
        // 現在のカテゴリ以降を確認
        for i in (currentIndex + 1)..<availableCategories.count {
            let category = availableCategories[i]
            if !PhotoStorageService.shared.hasPhotoForDate(date, categoryId: category.id) {
                return category
            }
        }
        
        // 現在のカテゴリ以前を確認（ラップアラウンド）
        for i in 0..<currentIndex {
            let category = availableCategories[i]
            if !PhotoStorageService.shared.hasPhotoForDate(date, categoryId: category.id) {
                return category
            }
        }
        
        return nil
    }
    
    private func loadAllCategories() -> [PhotoCategory] {
        storedCategories() ?? [PhotoCategory.defaultCategory]
    }
    
    private func createCategoryDirectory(for category: PhotoCategory) {
        guard let documentsDir = documentsDirectory else { return }
        
        let photosDir = documentsDir.appendingPathComponent("Photos")
        let categoryDir = photosDir.appendingPathComponent(category.folderName)
        
        if !FileManager.default.fileExists(atPath: categoryDir.path) {
            try? FileManager.default.createDirectory(at: categoryDir, withIntermediateDirectories: true)
        }
    }
    
    func saveGuideline(for categoryId: String, guideline: BodyGuideline) {
        print("CategoryStorageService: saveGuideline called for category: \(categoryId)")
        var categories = loadAllCategories()
        
        if let index = categories.firstIndex(where: { $0.id == categoryId }) {
            print("CategoryStorageService: Found category at index \(index)")
            categories[index].guideline = guideline
            saveCategories(categories)
            print("CategoryStorageService: Guideline saved successfully")
            
        } else {
            print("CategoryStorageService: ERROR - Category not found with ID: \(categoryId)")
        }
    }
    
    func removeGuideline(for categoryId: String) {
        var categories = loadAllCategories()
        
        if let index = categories.firstIndex(where: { $0.id == categoryId }) {
            categories[index].guideline = nil
            saveCategories(categories)
        }
    }
}