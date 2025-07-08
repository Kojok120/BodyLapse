import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

class FaceBlurService {
    static let shared = FaceBlurService()
    
    private let context = CIContext()
    
    private init() {}
    
    func processImageAsync(_ image: UIImage) async -> UIImage {
        await withCheckedContinuation { continuation in
            processImage(image) { result in
                continuation.resume(returning: result ?? image)
            }
        }
    }
    
    func processImage(_ image: UIImage, completion: @escaping (UIImage?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            guard let self = self,
                  error == nil,
                  let results = request.results as? [VNFaceObservation],
                  !results.isEmpty else {
                completion(image)
                return
            }
            
            let blurredImage = self.blurFaces(in: image, faceObservations: results)
            completion(blurredImage)
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: self.imageOrientation(from: image.imageOrientation))
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform face detection: \(error)")
                DispatchQueue.main.async {
                    completion(image)
                }
            }
        }
    }
    
    private func blurFaces(in image: UIImage, faceObservations: [VNFaceObservation]) -> UIImage {
        guard let cgImage = image.cgImage,
              let ciImage = CIImage(image: image) else {
            return image
        }
        
        var outputImage = ciImage
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        
        for face in faceObservations {
            let boundingBox = VNImageRectForNormalizedRect(face.boundingBox, Int(imageSize.width), Int(imageSize.height))
            
            let expandedBox = expandBoundingBox(boundingBox, by: 1.4, in: imageSize)
            
            let croppedFace = ciImage.cropped(to: expandedBox)
            
            let blurFilter = CIFilter.gaussianBlur()
            blurFilter.inputImage = croppedFace
            blurFilter.radius = 150
            
            guard let blurredFace = blurFilter.outputImage else { continue }
            
            let compositedImage = blurredFace.composited(over: outputImage)
            
            outputImage = compositedImage.cropped(to: ciImage.extent)
        }
        
        if let cgOutput = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgOutput, scale: image.scale, orientation: image.imageOrientation)
        }
        
        return image
    }
    
    private func expandBoundingBox(_ box: CGRect, by factor: CGFloat, in imageSize: CGSize) -> CGRect {
        let expansion = (factor - 1.0) / 2.0
        let widthExpansion = box.width * expansion
        let heightExpansion = box.height * expansion
        
        let expandedBox = CGRect(
            x: max(0, box.minX - widthExpansion),
            y: max(0, box.minY - heightExpansion),
            width: min(imageSize.width - (box.minX - widthExpansion), box.width + (widthExpansion * 2)),
            height: min(imageSize.height - (box.minY - heightExpansion), box.height + (heightExpansion * 2))
        )
        
        return expandedBox
    }
    
    private func imageOrientation(from uiImageOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch uiImageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}