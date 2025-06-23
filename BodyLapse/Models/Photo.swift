import Foundation

struct Photo: Identifiable, Codable {
    let id: UUID
    let captureDate: Date
    let fileName: String
    let isFaceBlurred: Bool
    let bodyDetectionConfidence: Double?
    
    init(id: UUID = UUID(), captureDate: Date = Date(), fileName: String, isFaceBlurred: Bool = false, bodyDetectionConfidence: Double? = nil) {
        self.id = id
        self.captureDate = captureDate
        self.fileName = fileName
        self.isFaceBlurred = isFaceBlurred
        self.bodyDetectionConfidence = bodyDetectionConfidence
    }
    
    var fileURL: URL {
        PhotoStorageService.shared.documentsDirectory.appendingPathComponent(fileName)
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
}