import Foundation
import UIKit

class GuidelineStorageService {
    static let shared = GuidelineStorageService()
    
    private let guidelineKey = "BodyLapseGuideline"
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    // MARK: - レガシーサポート（デフォルトカテゴリ）
    // これらのメソッドはデフォルトカテゴリ用にCategoryStorageServiceに委譲
    
    func saveGuideline(_ guideline: BodyGuideline) {
        saveGuideline(guideline, for: PhotoCategory.defaultCategory.id)
    }
    
    func loadGuideline() -> BodyGuideline? {
        return loadGuideline(for: PhotoCategory.defaultCategory.id)
    }
    
    func deleteGuideline() {
        deleteGuideline(for: PhotoCategory.defaultCategory.id)
    }
    
    func hasGuideline() -> Bool {
        return hasGuideline(for: PhotoCategory.defaultCategory.id)
    }
    
    // MARK: - カテゴリベースのメソッド
    
    func saveGuideline(_ guideline: BodyGuideline, for categoryId: String) {
        CategoryStorageService.shared.saveGuideline(for: categoryId, guideline: guideline)
    }
    
    func loadGuideline(for categoryId: String) -> BodyGuideline? {
        return CategoryStorageService.shared.getCategoryById(categoryId)?.guideline
    }
    
    func deleteGuideline(for categoryId: String) {
        CategoryStorageService.shared.removeGuideline(for: categoryId)
    }
    
    func hasGuideline(for categoryId: String) -> Bool {
        return loadGuideline(for: categoryId) != nil
    }
    
    func getAllGuidelines() -> [(categoryId: String, guideline: BodyGuideline)] {
        let categories = CategoryStorageService.shared.getActiveCategories()
        
        return categories.compactMap { category in
            guard let guideline = category.guideline else { return nil }
            return (category.id, guideline)
        }
    }
}