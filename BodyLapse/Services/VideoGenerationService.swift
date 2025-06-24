import Foundation
import UIKit
import AVFoundation
import Photos

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
            
            do {
                let videoURL = try self.createVideo(
                    from: filteredPhotos,
                    options: options,
                    progress: progress
                )
                
                Task {
                    do {
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
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func createVideo(
        from photos: [Photo],
        options: VideoGenerationOptions,
        progress: @escaping (Float) -> Void
    ) throws -> URL {
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
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
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
            autoreleasepool {
                guard let image = PhotoStorageService.shared.loadImage(for: photo) else { return }
                
                // Apply face blur if enabled
                let imageToProcess: UIImage
                if options.blurFaces {
                    let semaphore = DispatchSemaphore(value: 0)
                    var blurredImage: UIImage?
                    
                    FaceBlurService.shared.processImage(image) { result in
                        blurredImage = result ?? image
                        semaphore.signal()
                    }
                    
                    semaphore.wait()
                    imageToProcess = blurredImage ?? image
                } else {
                    imageToProcess = image
                }
                
                // Process image
                let processedImage = processImage(
                    imageToProcess,
                    targetSize: options.videoSize,
                    addWatermark: options.addWatermark
                )
                
                // Convert to pixel buffer
                if let pixelBuffer = pixelBuffer(from: processedImage, size: options.videoSize) {
                    // Wait for input to be ready
                    while !videoWriterInput.isReadyForMoreMediaData {
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                    
                    // Append pixel buffer
                    pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: currentTime)
                    currentTime = CMTimeAdd(currentTime, options.frameDuration)
                }
                
                // Update progress
                let progressValue = Float(index + 1) / Float(totalPhotos)
                DispatchQueue.main.async {
                    progress(progressValue)
                }
            }
        }
        
        // Finish writing
        videoWriterInput.markAsFinished()
        
        let semaphore = DispatchSemaphore(value: 0)
        videoWriter.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()
        
        guard videoWriter.status == .completed else {
            throw VideoGenerationError.videoCreationFailed
        }
        
        return outputURL
    }
    
    private func processImage(_ image: UIImage, targetSize: CGSize, addWatermark: Bool) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(targetSize, true, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return image }
        
        // Fill background
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: targetSize))
        
        // Calculate aspect fit rect
        let imageSize = image.size
        let widthRatio = targetSize.width / imageSize.width
        let heightRatio = targetSize.height / imageSize.height
        let scale = min(widthRatio, heightRatio)
        
        let scaledSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        
        let drawRect = CGRect(
            x: (targetSize.width - scaledSize.width) / 2,
            y: (targetSize.height - scaledSize.height) / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
        
        // Draw image
        image.draw(in: drawRect)
        
        // Add watermark if needed
        if addWatermark {
            addWatermarkToContext(context, in: CGRect(origin: .zero, size: targetSize))
        }
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    private func addWatermarkToContext(_ context: CGContext, in rect: CGRect) {
        let watermarkText = "BodyLapse"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.7)
        ]
        
        let textSize = watermarkText.size(withAttributes: attributes)
        let textRect = CGRect(
            x: rect.width - textSize.width - 20,
            y: rect.height - textSize.height - 20,
            width: textSize.width,
            height: textSize.height
        )
        
        watermarkText.draw(in: textRect, withAttributes: attributes)
    }
    
    private func pixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        let options: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: kCFBooleanTrue!
        ]
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,
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
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }
        
        UIGraphicsPushContext(context)
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        UIGraphicsPopContext()
        
        return buffer
    }
}