import Foundation
import UIKit
import AVFoundation
import Photos

extension UIImage {
    func fixedOrientation() -> UIImage {
        // No-op if the orientation is already correct
        if imageOrientation == .up {
            return self
        }
        
        // We need to calculate the proper transformation to make the image upright.
        var transform = CGAffineTransform.identity
        
        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: -.pi / 2)
        case .up, .upMirrored:
            break
        @unknown default:
            break
        }
        
        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .up, .down, .left, .right:
            break
        @unknown default:
            break
        }
        
        // Now we draw the underlying CGImage into a new context, applying the transform
        guard let cgImage = cgImage,
              let colorSpace = cgImage.colorSpace,
              let context = CGContext(data: nil,
                                     width: Int(size.width),
                                     height: Int(size.height),
                                     bitsPerComponent: cgImage.bitsPerComponent,
                                     bytesPerRow: 0,
                                     space: colorSpace,
                                     bitmapInfo: cgImage.bitmapInfo.rawValue) else {
            return self
        }
        
        context.concatenate(transform)
        
        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
        default:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        }
        
        // And now we just create a new UIImage from the drawing context
        guard let newCGImage = context.makeImage() else {
            return self
        }
        
        return UIImage(cgImage: newCGImage)
    }
}

class VideoGenerationService {
    static let shared = VideoGenerationService()
    
    private init() {}
    
    enum VideoGenerationError: LocalizedError {
        case noPhotosFound
        case videoCreationFailed
        case exportFailed
        case cancelled
        
        var errorDescription: String? {
            switch self {
            case .noPhotosFound:
                return "No photos found in the selected period"
            case .videoCreationFailed:
                return "Failed to create video"
            case .exportFailed:
                return "Failed to export video"
            case .cancelled:
                return "Video generation was cancelled"
            }
        }
    }
    
    struct VideoGenerationOptions {
        let frameDuration: CMTime
        let videoSize: CGSize
        let addWatermark: Bool
        let transitionStyle: TransitionStyle
        let blurFaces: Bool
        
        enum TransitionStyle {
            case none
            case fade
            case crossDissolve
        }
        
        static let `default` = VideoGenerationOptions(
            frameDuration: CMTime(value: 1, timescale: 4), // 0.25 seconds per frame
            videoSize: CGSize(width: 1080, height: 1920), // Portrait HD
            addWatermark: true,
            transitionStyle: .fade,
            blurFaces: false
        )
    }
    
    func generateVideo(
        from photos: [Photo],
        in dateRange: ClosedRange<Date>,
        options: VideoGenerationOptions = .default,
        progress: @escaping (Float) -> Void,
        completion: @escaping (Result<Video, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Filter photos within date range
            let filteredPhotos = photos.filter { photo in
                dateRange.contains(photo.captureDate)
            }.sorted { $0.captureDate < $1.captureDate }
            
            guard !filteredPhotos.isEmpty else {
                DispatchQueue.main.async {
                    completion(.failure(VideoGenerationError.noPhotosFound))
                }
                return
            }
            
            Task {
                do {
                    let videoURL = try await self.createVideoAsync(
                        from: filteredPhotos,
                        options: options,
                        progress: progress
                    )
                    
                    // Save video to storage
                    let video = try await VideoStorageService.shared.saveVideo(
                        videoURL,
                        startDate: dateRange.lowerBound,
                        endDate: dateRange.upperBound,
                        frameCount: filteredPhotos.count
                    )
                    
                    // Clean up temporary file
                    try? FileManager.default.removeItem(at: videoURL)
                    
                    await MainActor.run {
                        completion(.success(video))
                    }
                } catch {
                    await MainActor.run {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    private func createVideoAsync(
        from photos: [Photo],
        options: VideoGenerationOptions,
        progress: @escaping (Float) -> Void
    ) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        // Remove any existing file
        try? FileManager.default.removeItem(at: outputURL)
        
        // Create video writer
        let videoWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        
        // Configure video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: options.videoSize.width,
            AVVideoHeightKey: options.videoSize.height
        ]
        
        let videoWriterInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: videoSettings
        )
        videoWriterInput.expectsMediaDataInRealTime = false
        
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoWriterInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: options.videoSize.width,
                kCVPixelBufferHeightKey as String: options.videoSize.height
            ]
        )
        
        videoWriter.add(videoWriterInput)
        
        // Start writing
        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: .zero)
        
        // Process photos
        var currentTime = CMTime.zero
        let totalPhotos = photos.count
        
        for (index, photo) in photos.enumerated() {
            guard let image = PhotoStorageService.shared.loadImage(for: photo) else { continue }
            
            // Apply face blur if enabled
            let imageToProcess: UIImage
            if options.blurFaces {
                imageToProcess = await FaceBlurService.shared.processImageAsync(image)
            } else {
                imageToProcess = image
            }
            
            // Convert to pixel buffer
            if let pixelBuffer = autoreleasepool(invoking: { () -> CVPixelBuffer? in
                createPixelBuffer(
                    from: imageToProcess,
                    size: options.videoSize,
                    addWatermark: options.addWatermark
                )
            }) {
                // Wait for input to be ready using async
                while !videoWriterInput.isReadyForMoreMediaData {
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }
                
                // Append pixel buffer
                pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: currentTime)
                currentTime = CMTimeAdd(currentTime, options.frameDuration)
            }
            
            // Update progress
            let progressValue = Float(index + 1) / Float(totalPhotos)
            await MainActor.run {
                progress(progressValue)
            }
        }
        
        // Finish writing
        videoWriterInput.markAsFinished()
        
        await withCheckedContinuation { continuation in
            videoWriter.finishWriting {
                continuation.resume()
            }
        }
        
        guard videoWriter.status == .completed else {
            throw VideoGenerationError.videoCreationFailed
        }
        
        return outputURL
    }
    
    
    
    private func createPixelBuffer(from image: UIImage, size: CGSize, addWatermark: Bool) -> CVPixelBuffer? {
        // Fix orientation if needed
        let orientedImage = image.fixedOrientation()
        
        let options: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: kCFBooleanTrue!
        ]
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            options as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: pixelData,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return nil
        }
        
        // Fill background with black
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        // Calculate aspect fit rect
        let imageSize = orientedImage.size
        let widthRatio = size.width / imageSize.width
        let heightRatio = size.height / imageSize.height
        let scale = min(widthRatio, heightRatio)
        
        let scaledSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        
        let drawRect = CGRect(
            x: (size.width - scaledSize.width) / 2,
            y: (size.height - scaledSize.height) / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
        
        // Draw the image
        if let cgImage = orientedImage.cgImage {
            context.draw(cgImage, in: drawRect)
        }
        
        // Add watermark if needed
        if addWatermark {
            let watermarkText = "BodyLapse"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.7)
            ]
            
            let textSize = watermarkText.size(withAttributes: attributes)
            let textRect = CGRect(
                x: size.width - textSize.width - 20,
                y: size.height - textSize.height - 20,
                width: textSize.width,
                height: textSize.height
            )
            
            // Save current context
            context.saveGState()
            
            // Flip coordinate system for text drawing
            context.translateBy(x: 0, y: size.height)
            context.scaleBy(x: 1.0, y: -1.0)
            
            // Draw text
            UIGraphicsPushContext(context)
            watermarkText.draw(in: CGRect(x: textRect.origin.x, y: size.height - textRect.maxY, width: textRect.width, height: textRect.height), withAttributes: attributes)
            UIGraphicsPopContext()
            
            // Restore context
            context.restoreGState()
        }
        
        return buffer
    }
}