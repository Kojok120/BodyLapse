//
//  PhotoCategory.swift
//  BodyLapse
//
//  Created by Anthropic on 2025/01/01.
//

import Foundation

struct PhotoCategory: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var order: Int
    let isDefault: Bool
    var guideline: BodyGuideline?
    let createdDate: Date
    var isActive: Bool
    
    static let defaultCategory = PhotoCategory(
        id: "front",
        name: "category.default.front".localized,
        order: 0,
        isDefault: true,
        guideline: nil,
        createdDate: Date(),
        isActive: true
    )
    
    static let maxCustomCategories = 3
    
    var displayName: String {
        return name
    }
    
    var isCustom: Bool {
        return !isDefault
    }
    
    static func createCustomCategory(name: String, order: Int) -> PhotoCategory {
        let customId = "custom\(UUID().uuidString.prefix(8))"
        return PhotoCategory(
            id: customId,
            name: name,
            order: order,
            isDefault: false,
            guideline: nil,
            createdDate: Date(),
            isActive: true
        )
    }
    
    static func == (lhs: PhotoCategory, rhs: PhotoCategory) -> Bool {
        return lhs.id == rhs.id
    }
}

extension PhotoCategory {
    var folderName: String {
        return id
    }
    
    var canBeDeleted: Bool {
        return isCustom && isActive
    }
    
    var canBeRenamed: Bool {
        return isCustom
    }
}