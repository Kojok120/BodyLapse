import SwiftUI
import Vision
import CoreImage
#if os(iOS)
import UIKit
#endif

class BodyContourService {
    static let shared = BodyContourService()
    
    private init() {}
    
    enum ContourError: LocalizedError {
        case noPersonDetected
        case contourExtractionFailed
        case imageProcessingFailed
        
        var errorDescription: String? {
            switch self {
            case .noPersonDetected:
                return "No person detected in the image"
            case .contourExtractionFailed:
                return "Failed to extract body contour"
            case .imageProcessingFailed:
                return "Failed to process image"
            }
        }
    }
    
    #if os(iOS)
    func detectBodyContour(from image: UIImage, completion: @escaping (Result<[CGPoint], Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(ContourError.imageProcessingFailed))
            return
        }
        
        // Create person segmentation request
        let request = VNGeneratePersonSegmentationRequest { [weak self] request, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let observations = request.results as? [VNPixelBufferObservation],
                  let observation = observations.first else {
                DispatchQueue.main.async {
                    completion(.failure(ContourError.noPersonDetected))
                }
                return
            }
            
            // Extract contour from segmentation mask
            self?.extractContour(from: observation.pixelBuffer, imageSize: CGSize(width: cgImage.width, height: cgImage.height)) { result in
                DispatchQueue.main.async {
                    completion(result)
                }
            }
        }
        
        request.qualityLevel = .accurate
        
        // Perform request
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func extractContour(from pixelBuffer: CVPixelBuffer, imageSize: CGSize, completion: @escaping (Result<[CGPoint], Error>) -> Void) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard context.createCGImage(ciImage, from: ciImage.extent) != nil else {
            completion(.failure(ContourError.imageProcessingFailed))
            return
        }
        
        // Convert to binary image and find contour
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // Simple edge detection - find the outline of the person
        var contourPoints: [CGPoint] = []
        
        // Scan from multiple angles to find body outline
        let scanAngles = stride(from: 0, to: 360, by: 5)
        let centerX = CGFloat(width) / 2
        let centerY = CGFloat(height) / 2
        let maxRadius = min(centerX, centerY)
        
        for angle in scanAngles {
            let radians = CGFloat(angle) * .pi / 180
            
            // Scan outward from center
            for radius in stride(from: 0, to: maxRadius, by: 2) {
                let x = centerX + radius * cos(radians)
                let y = centerY + radius * sin(radians)
                
                if x >= 0 && x < CGFloat(width) && y >= 0 && y < CGFloat(height) {
                    // Check if this pixel is part of the person
                    if isPersonPixel(at: CGPoint(x: x, y: y), in: pixelBuffer) {
                        // Scale to original image size
                        let scaledX = x * imageSize.width / CGFloat(width)
                        let scaledY = y * imageSize.height / CGFloat(height)
                        contourPoints.append(CGPoint(x: scaledX, y: scaledY))
                        break
                    }
                }
            }
        }
        
        // Smooth the contour
        let smoothedContour = smoothContour(contourPoints)
        completion(.success(smoothedContour))
    }
    
    private func isPersonPixel(at point: CGPoint, in pixelBuffer: CVPixelBuffer) -> Bool {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return false }
        
        let x = Int(point.x)
        let y = Int(point.y)
        
        guard x >= 0 && x < width && y >= 0 && y < height else { return false }
        
        let pixel = baseAddress.assumingMemoryBound(to: UInt8.self)
        let offset = y * bytesPerRow + x
        
        // Check if pixel value is above threshold (person detected)
        return pixel[offset] > 128
    }
    
    private func smoothContour(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count > 3 else { return points }
        
        var smoothed: [CGPoint] = []
        let windowSize = 3
        
        for i in 0..<points.count {
            var sumX: CGFloat = 0
            var sumY: CGFloat = 0
            var count = 0
            
            for j in -windowSize...windowSize {
                let index = (i + j + points.count) % points.count
                sumX += points[index].x
                sumY += points[index].y
                count += 1
            }
            
            smoothed.append(CGPoint(x: sumX / CGFloat(count), y: sumY / CGFloat(count)))
        }
        
        return smoothed
    }
    
    // Create a preview image with the contour overlay
    func createContourPreview(image: UIImage, contour: [CGPoint]) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        // Draw original image
        image.draw(at: .zero)
        
        // Draw contour
        guard let context = UIGraphicsGetCurrentContext(), contour.count > 2 else {
            return image
        }
        
        context.setStrokeColor(UIColor.green.cgColor)
        context.setLineWidth(3.0)
        
        context.beginPath()
        context.move(to: contour[0])
        
        for i in 1..<contour.count {
            context.addLine(to: contour[i])
        }
        
        context.closePath()
        context.strokePath()
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    #endif
}