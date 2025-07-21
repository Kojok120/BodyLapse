import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

class FaceBlurService {
    static let shared = FaceBlurService()
    
    private let context = CIContext()
    
    enum BlurMethod {
        case strongBlur   // 強力な多段階ぼかし（デフォルト）
        case blackout     // 完全な黒塗り（最も確実）
    }
    
    private init() {}
    
    func processImageAsync(_ image: UIImage, blurMethod: BlurMethod = .strongBlur) async -> UIImage {
        await withCheckedContinuation { continuation in
            processImage(image, blurMethod: blurMethod) { result in
                continuation.resume(returning: result ?? image)
            }
        }
    }
    
    func processImage(_ image: UIImage, blurMethod: BlurMethod = .strongBlur, completion: @escaping (UIImage?) -> Void) {
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
            
            let blurredImage = self.blurFaces(in: image, faceObservations: results, blurMethod: blurMethod)
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
    
    private func blurFaces(in image: UIImage, faceObservations: [VNFaceObservation], blurMethod: BlurMethod) -> UIImage {
        guard let cgImage = image.cgImage,
              let ciImage = CIImage(image: image) else {
            return image
        }
        
        var outputImage = ciImage
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        
        for face in faceObservations {
            let boundingBox = VNImageRectForNormalizedRect(face.boundingBox, Int(imageSize.width), Int(imageSize.height))
            
            // 拡大係数を2.0に増加（100%拡張でより大きな範囲をカバー）
            let expandedBox = expandBoundingBox(boundingBox, by: 2.0, in: imageSize)
            
            // 選択された処理方法に応じて適用
            switch blurMethod {
            case .strongBlur:
                outputImage = applySecureFaceBlur(to: outputImage, in: expandedBox)
            case .blackout:
                outputImage = applyBlackoutFaceBlur(to: outputImage, in: expandedBox)
            }
        }
        
        if let cgOutput = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgOutput, scale: image.scale, orientation: image.imageOrientation)
        }
        
        return image
    }
    
    // 透けない確実な顔ぼかし処理
    private func applySecureFaceBlur(to image: CIImage, in region: CGRect) -> CIImage {
        // 1. 該当領域を切り取り
        let croppedRegion = image.cropped(to: region)
        
        // 2. 多段階ガウシアンブラーで完全にぼかす
        var blurredRegion = croppedRegion
        
        // 第1段階: 強力なぼかし（radius: 100）
        if let blurFilter1 = CIFilter(name: "CIGaussianBlur") {
            blurFilter1.setValue(blurredRegion, forKey: kCIInputImageKey)
            blurFilter1.setValue(100, forKey: kCIInputRadiusKey)
            if let output1 = blurFilter1.outputImage {
                blurredRegion = output1
            }
        }
        
        // 第2段階: さらに強力なぼかし（radius: 150）
        if let blurFilter2 = CIFilter(name: "CIGaussianBlur") {
            blurFilter2.setValue(blurredRegion, forKey: kCIInputImageKey)
            blurFilter2.setValue(150, forKey: kCIInputRadiusKey)
            if let output2 = blurFilter2.outputImage {
                blurredRegion = output2
            }
        }
        
        // 3. ぼかし範囲を元画像の範囲に調整
        blurredRegion = blurredRegion.cropped(to: region)
        
        // 4. Source Over合成で完全に置き換え
        let sourceOverFilter = CIFilter(name: "CISourceOverCompositing")!
        sourceOverFilter.setValue(blurredRegion, forKey: kCIInputImageKey)
        sourceOverFilter.setValue(image, forKey: kCIInputBackgroundImageKey)
        
        return sourceOverFilter.outputImage ?? image
    }
    
    // より確実な黒塗り処理オプション（必要に応じて使用）
    private func applyBlackoutFaceBlur(to image: CIImage, in region: CGRect) -> CIImage {
        // 完全な黒い矩形を作成
        guard let blackGenerator = CIFilter(name: "CIConstantColorGenerator") else { return image }
        blackGenerator.setValue(CIColor(red: 0, green: 0, blue: 0, alpha: 1), forKey: kCIInputColorKey)
        
        guard let blackImage = blackGenerator.outputImage?.cropped(to: region) else { return image }
        
        // Source Over合成で完全に置き換え
        let sourceOverFilter = CIFilter(name: "CISourceOverCompositing")!
        sourceOverFilter.setValue(blackImage, forKey: kCIInputImageKey)
        sourceOverFilter.setValue(image, forKey: kCIInputBackgroundImageKey)
        
        return sourceOverFilter.outputImage ?? image
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