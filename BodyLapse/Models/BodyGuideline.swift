import Foundation
import CoreGraphics

struct BodyGuideline: Codable {
    let points: [CGPoint]
    let imageSize: CGSize
    let createdDate: Date
    let isFrontCamera: Bool
    
    enum CodingKeys: String, CodingKey {
        case points
        case imageSize
        case createdDate
        case isFrontCamera
    }
    
    init(points: [CGPoint], imageSize: CGSize, isFrontCamera: Bool = false) {
        self.points = points
        self.imageSize = imageSize
        self.createdDate = Date()
        self.isFrontCamera = isFrontCamera
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.points = try container.decode([CGPoint].self, forKey: .points)
        self.imageSize = try container.decode(CGSize.self, forKey: .imageSize)
        self.createdDate = try container.decode(Date.self, forKey: .createdDate)
        // 後方互換性のためデフォルトはfalse
        self.isFrontCamera = try container.decodeIfPresent(Bool.self, forKey: .isFrontCamera) ?? false
    }
    
    // ポイントを相対座標（0〜1の範囲）に変換
    var normalizedPoints: [CGPoint] {
        return points.map { point in
            CGPoint(
                x: point.x / imageSize.width,
                y: point.y / imageSize.height
            )
        }
    }
    
    // 指定サイズにスケーリングしたポイントを取得
    func scaledPoints(for size: CGSize) -> [CGPoint] {
        return normalizedPoints.map { point in
            CGPoint(
                x: point.x * size.width,
                y: point.y * size.height
            )
        }
    }
}