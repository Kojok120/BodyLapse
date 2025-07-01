import Foundation

struct Photo: Identifiable, Codable {
    let id: UUID
    let captureDate: Date
    let fileName: String
    let categoryId: String
    let isFaceBlurred: Bool
    let bodyDetectionConfidence: Double?
    var weight: Double?
    var bodyFatPercentage: Double?
    
    init(id: UUID = UUID(), captureDate: Date = Date(), fileName: String, categoryId: String = PhotoCategory.defaultCategory.id, isFaceBlurred: Bool = false, bodyDetectionConfidence: Double? = nil, weight: Double? = nil, bodyFatPercentage: Double? = nil) {
        self.id = id
        self.captureDate = captureDate
        self.fileName = fileName
        self.categoryId = categoryId
        self.isFaceBlurred = isFaceBlurred
        self.bodyDetectionConfidence = bodyDetectionConfidence
        self.weight = weight
        self.bodyFatPercentage = bodyFatPercentage
    }
    
    var fileURL: URL? {
        PhotoStorageService.shared.documentsDirectory?
            .appendingPathComponent("Photos")
            .appendingPathComponent(categoryId)
            .appendingPathComponent(fileName)
    }
}

extension Photo {
    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    var formattedDate: String {
        Self.dateFormatter.string(from: captureDate)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, captureDate, fileName, categoryId, isFaceBlurred, bodyDetectionConfidence, weight, bodyFatPercentage
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.captureDate = try container.decode(Date.self, forKey: .captureDate)
        self.fileName = try container.decode(String.self, forKey: .fileName)
        self.categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId) ?? PhotoCategory.defaultCategory.id
        self.isFaceBlurred = try container.decode(Bool.self, forKey: .isFaceBlurred)
        self.bodyDetectionConfidence = try container.decodeIfPresent(Double.self, forKey: .bodyDetectionConfidence)
        self.weight = try container.decodeIfPresent(Double.self, forKey: .weight)
        self.bodyFatPercentage = try container.decodeIfPresent(Double.self, forKey: .bodyFatPercentage)
    }
}