import Foundation
import CoreGraphics

struct BodyGuideline: Codable {
    let points: [CGPoint]
    let imageSize: CGSize
    let createdDate: Date
    
    init(points: [CGPoint], imageSize: CGSize) {
        self.points = points
        self.imageSize = imageSize
        self.createdDate = Date()
    }
    
    // Convert points to relative coordinates (0-1 range)
    var normalizedPoints: [CGPoint] {
        return points.map { point in
            CGPoint(
                x: point.x / imageSize.width,
                y: point.y / imageSize.height
            )
        }
    }
    
    // Get points scaled to a specific size
    func scaledPoints(for size: CGSize) -> [CGPoint] {
        return normalizedPoints.map { point in
            CGPoint(
                x: point.x * size.width,
                y: point.y * size.height
            )
        }
    }
}