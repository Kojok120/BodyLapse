import Foundation

struct Video: Identifiable, Codable {
    let id: UUID
    let fileName: String
    let createdDate: Date
    let duration: TimeInterval
    let startDate: Date
    let endDate: Date
    let frameCount: Int
    let thumbnailFileName: String?
    
    init(
        id: UUID = UUID(),
        fileName: String,
        createdDate: Date = Date(),
        duration: TimeInterval,
        startDate: Date,
        endDate: Date,
        frameCount: Int,
        thumbnailFileName: String? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.createdDate = createdDate
        self.duration = duration
        self.startDate = startDate
        self.endDate = endDate
        self.frameCount = frameCount
        self.thumbnailFileName = thumbnailFileName
    }
    
    var fileURL: URL {
        VideoStorageService.shared.videosDirectory.appendingPathComponent(fileName)
    }
    
    var thumbnailURL: URL? {
        guard let thumbnailFileName = thumbnailFileName else { return nil }
        return VideoStorageService.shared.thumbnailsDirectory.appendingPathComponent(thumbnailFileName)
    }
}

extension Video {
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "0:00"
    }
    
    var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}