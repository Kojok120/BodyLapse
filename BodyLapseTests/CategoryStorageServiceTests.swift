import Foundation
import Testing
@testable import BodyLapse

// カテゴリは Documents を共有するので、直列の BodyLapseTests に入れる
extension BodyLapseTests {

    /// 保存した内容がそのまま読めること (読むたびにディスクから読まず、保存のときに入れ替える)
    @Test
    func testCategoriesReflectSavesWithoutRereadingDisk() throws {
        let service = CategoryStorageService.shared
        let original = service.loadCategories()
        defer { service.saveCategories(original.isEmpty ? [PhotoCategory.defaultCategory] : original) }

        var custom = PhotoCategory(
            id: "test-\(UUID().uuidString)", name: "Side", order: 2, isDefault: false,
            guideline: nil, createdDate: Date(), isActive: true
        )
        let hidden = PhotoCategory(
            id: "test-\(UUID().uuidString)", name: "Back", order: 1, isDefault: false,
            guideline: nil, createdDate: Date(), isActive: false
        )
        service.saveCategories([custom, PhotoCategory.defaultCategory, hidden])

        let loaded = service.loadCategories()
        #expect(loaded.map(\.id) == [PhotoCategory.defaultCategory.id, custom.id])
        #expect(service.getCategoryById(hidden.id) == nil)

        custom.name = "Side 2"
        service.updateCategory(custom)
        #expect(service.getCategoryById(custom.id)?.name == "Side 2")
    }
}
