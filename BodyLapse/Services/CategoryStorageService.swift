//
//  CategoryStorageService.swift
//  BodyLapse
//
//  Created by Anthropic on 2025/01/01.
//

import Foundation

class CategoryStorageService {
    static let shared = CategoryStorageService()
    
    private let categoriesKey = "BodyLapseCategories"
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
        guard let url = categoriesFileURL,
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let categories = try? JSONDecoder().decode([PhotoCategory].self, from: data) else {
            return []
        }
        
        return categories.filter { $0.isActive }.sorted { $0.order < $1.order }
    }
    
    func saveCategories(_ categories: [PhotoCategory]) {
        guard let url = categoriesFileURL else { return }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(categories)
            try data.write(to: url)
        } catch {
            print("Error saving categories: \(error)")
        }
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
        
        // Post notification for category change
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
            
            // Delete all photos associated with this category
            deletePhotosForCategory(id: id)
            
            // Remove guideline for this category
            removeGuideline(for: id)
            
            // Post notification for category change
            NotificationCenter.default.post(name: Notification.Name("CategoriesUpdated"), object: nil)
        }
    }
    
    private func deletePhotosForCategory(id: String) {
        // Get the documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        let categoryFolderPath = documentsPath.appendingPathComponent("Photos").appendingPathComponent(id)
        
        // Remove the entire category folder if it exists
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
    
    func getActiveCategoriesForUser(isPremium: Bool) -> [PhotoCategory] {
        let categories = loadCategories()
        
        // For free users, return only default category
        if !isPremium {
            return categories.filter { $0.isDefault }
        }
        
        return categories
    }
    
    func updateCategoryOrder(_ categories: [PhotoCategory]) {
        var allCategories = loadAllCategories()
        
        for (index, category) in categories.enumerated() {
            if let existingIndex = allCategories.firstIndex(where: { $0.id == category.id }) {
                allCategories[existingIndex].order = index
            }
        }
        
        saveCategories(allCategories)
    }
    
    private func loadAllCategories() -> [PhotoCategory] {
        guard let url = categoriesFileURL,
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let categories = try? JSONDecoder().decode([PhotoCategory].self, from: data) else {
            return [PhotoCategory.defaultCategory]
        }
        
        return categories
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
        var categories = loadAllCategories()
        
        if let index = categories.firstIndex(where: { $0.id == categoryId }) {
            categories[index].guideline = guideline
            saveCategories(categories)
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