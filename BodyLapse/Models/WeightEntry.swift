import Foundation

struct WeightEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let weight: Double // Always stored in kg
    let bodyFatPercentage: Double?
    let linkedPhotoID: String?
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        date: Date,
        weight: Double,
        bodyFatPercentage: Double? = nil,
        linkedPhotoID: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.weight = weight
        self.bodyFatPercentage = bodyFatPercentage
        self.linkedPhotoID = linkedPhotoID
        self.createdAt = createdAt
    }
}

extension WeightEntry {
    // Convert weight based on user preference
    func displayWeight(unit: UserSettings.WeightUnit) -> Double {
        switch unit {
        case .kg:
            return weight
        case .lbs:
            return weight * 2.20462
        }
    }
}