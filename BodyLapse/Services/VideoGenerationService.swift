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
        let layout: VideoLayout
        let selectedCategories: [String]
        let showDate: Bool
        let showGraph: Bool
        
        enum TransitionStyle {
            case none
            case fade
            case crossDissolve
        }
        
        enum VideoLayout {
            case single
            case sideBySide
        }
        
        static let `default` = VideoGenerationOptions(
            frameDuration: CMTime(value: 1, timescale: 4), // 0.25 seconds per frame
            videoSize: CGSize(width: 1080, height: 1920), // Portrait HD
            addWatermark: true,
            transitionStyle: .fade,
            blurFaces: false,
            layout: .single,
            selectedCategories: [],
            showDate: true,
            showGraph: false
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
            let filteredPhotos: [Photo]
            
            if options.layout == .single || options.selectedCategories.isEmpty {
                // Single category video - filter by first selected category or all photos
                let categoryId = options.selectedCategories.first
                let calendar = Calendar.current
                filteredPhotos = photos.filter { photo in
                    let photoDate = calendar.startOfDay(for: photo.captureDate)
                    let rangeStart = calendar.startOfDay(for: dateRange.lowerBound)
                    let rangeEnd = calendar.startOfDay(for: dateRange.upperBound)
                    return photoDate >= rangeStart && photoDate <= rangeEnd &&
                    (categoryId == nil || photo.categoryId == categoryId)
                }.sorted { $0.captureDate < $1.captureDate }
            } else {
                // Side-by-side video - filter by selected categories only
                let calendar = Calendar.current
                filteredPhotos = photos.filter { photo in
                    let photoDate = calendar.startOfDay(for: photo.captureDate)
                    let rangeStart = calendar.startOfDay(for: dateRange.lowerBound)
                    let rangeEnd = calendar.startOfDay(for: dateRange.upperBound)
                    return photoDate >= rangeStart && photoDate <= rangeEnd &&
                    options.selectedCategories.contains(photo.categoryId)
                }.sorted { $0.captureDate < $1.captureDate }
            }
            
            guard !filteredPhotos.isEmpty else {
                DispatchQueue.main.async {
                    completion(.failure(VideoGenerationError.noPhotosFound))
                }
                return
            }
            
            print("[VideoGeneration] Date range: \(dateRange.lowerBound) to \(dateRange.upperBound)")
            print("[VideoGeneration] Total photos: \(photos.count), Filtered photos: \(filteredPhotos.count)")
            
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
        
        // Load weight entries if graph is enabled
        var weightEntries: [WeightEntry] = []
        var dateRange: ClosedRange<Date>? = nil
        
        if options.showGraph && !photos.isEmpty {
            // Calculate date range from photos
            let sortedDates = photos.map { $0.captureDate }.sorted()
            if let startDate = sortedDates.first, let endDate = sortedDates.last {
                dateRange = startDate...endDate
                
                // Load weight entries for the date range
                do {
                    weightEntries = try await WeightStorageService.shared.getEntries(
                        from: startDate,
                        to: endDate
                    )
                } catch {
                    // Continue without weight data if loading fails
                    print("Failed to load weight entries: \(error)")
                }
            }
        }
        
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
        
        if options.layout == .single || options.selectedCategories.count <= 1 {
            // Single category video processing
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
                        addWatermark: options.addWatermark,
                        showDate: options.showDate,
                        date: photo.captureDate,
                        showGraph: options.showGraph,
                        weightEntries: weightEntries,
                        dateRange: dateRange
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
        } else {
            // Side-by-side video processing
            // Photos are already filtered by selected categories
            let photosByDate = Dictionary(grouping: photos) { photo in
                Calendar.current.startOfDay(for: photo.captureDate)
            }
            
            let sortedDates = photosByDate.keys.sorted()
            let totalFrames = sortedDates.count
            
            for (index, date) in sortedDates.enumerated() {
                let photosForDate = photosByDate[date] ?? []
                
                // Get photos for each selected category
                var categoryPhotos: [String: UIImage] = [:]
                for categoryId in options.selectedCategories {
                    if let photo = photosForDate.first(where: { $0.categoryId == categoryId }),
                       let image = PhotoStorageService.shared.loadImage(for: photo) {
                        // Apply face blur if enabled
                        if options.blurFaces {
                            categoryPhotos[categoryId] = await FaceBlurService.shared.processImageAsync(image)
                        } else {
                            categoryPhotos[categoryId] = image
                        }
                    }
                }
                
                // Only create frame if we have at least one photo
                if !categoryPhotos.isEmpty {
                    // Convert to pixel buffer
                    if let pixelBuffer = autoreleasepool(invoking: { () -> CVPixelBuffer? in
                        createSideBySidePixelBuffer(
                            from: categoryPhotos,
                            categories: options.selectedCategories,
                            size: options.videoSize,
                            addWatermark: options.addWatermark,
                            showDate: options.showDate,
                            date: date,
                            showGraph: options.showGraph,
                            weightEntries: weightEntries,
                            dateRange: dateRange
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
                }
                
                // Update progress
                let progressValue = Float(index + 1) / Float(totalFrames)
                await MainActor.run {
                    progress(progressValue)
                }
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
    
    
    
    private func createPixelBuffer(from image: UIImage, size: CGSize, addWatermark: Bool, showDate: Bool = false, date: Date? = nil, showGraph: Bool = false, weightEntries: [WeightEntry]? = nil, dateRange: ClosedRange<Date>? = nil) -> CVPixelBuffer? {
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
        
        // Reserve space for graph if needed
        let availableHeight = showGraph ? size.height * 0.75 : size.height // Reserve 25% for graph
        let availableSize = CGSize(width: size.width, height: availableHeight)
        
        let widthRatio = availableSize.width / imageSize.width
        let heightRatio = availableSize.height / imageSize.height
        let scale = min(widthRatio, heightRatio)
        
        let scaledSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        
        // Position image in the lower portion if graph is shown
        let yOffset = showGraph ? size.height * 0.20 : (size.height - scaledSize.height) / 2
        let drawRect = CGRect(
            x: (size.width - scaledSize.width) / 2,
            y: yOffset,
            width: scaledSize.width,
            height: scaledSize.height
        )
        
        // Draw the image
        if let cgImage = orientedImage.cgImage {
            context.draw(cgImage, in: drawRect)
        }
        
        // Add date if needed
        if showDate, let date = date {
            drawDate(date, in: context, size: size)
        }
        
        // Add graph if needed (premium feature)
        if showGraph, let weightEntries = weightEntries, let dateRange = dateRange, let currentDate = date {
            drawWeightChart(weightEntries: weightEntries, currentDate: currentDate, dateRange: dateRange, in: context, size: size)
        }
        
        // Add watermark if needed
        if addWatermark {
            drawWatermark(in: context, size: size)
        }
        
        return buffer
    }
    
    private func drawWatermark(in context: CGContext, size: CGSize) {
        // Save current context state
        context.saveGState()
        
        // Watermark text
        let watermarkText = "BodyLapse"
        
        // Calculate appropriate font size based on video size
        let baseFontSize: CGFloat = min(size.width, size.height) * 0.05 // 5% of smaller dimension
        let fontSize = max(baseFontSize, 30) // Minimum 30pt
        
        // Create watermark attributes with shadow
        let shadow = NSShadow()
        shadow.shadowColor = UIColor.black.withAlphaComponent(0.5)
        shadow.shadowOffset = CGSize(width: 2, height: 2)
        shadow.shadowBlurRadius = 4
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9),
            .shadow: shadow
        ]
        
        // Calculate text size
        let textSize = watermarkText.size(withAttributes: attributes)
        
        // Position in bottom right corner with padding
        let padding: CGFloat = min(size.width, size.height) * 0.04 // 4% padding
        let textRect = CGRect(
            x: size.width - textSize.width - padding,
            y: size.height - textSize.height - padding,
            width: textSize.width,
            height: textSize.height
        )
        
        // Create a semi-transparent background for better visibility
        let backgroundRect = textRect.insetBy(dx: -padding/2, dy: -padding/4)
        context.setFillColor(UIColor.black.withAlphaComponent(0.3).cgColor)
        context.fillEllipse(in: backgroundRect)
        
        // Flip coordinate system for text drawing
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        // Draw the watermark text
        UIGraphicsPushContext(context)
        let flippedRect = CGRect(
            x: textRect.origin.x,
            y: textRect.origin.y,
            width: textRect.width,
            height: textRect.height
        )
        watermarkText.draw(in: flippedRect, withAttributes: attributes)
        UIGraphicsPopContext()
        
        // Restore context state
        context.restoreGState()
    }
    
    private func drawDate(_ date: Date, in context: CGContext, size: CGSize) {
        // Save current context state
        context.saveGState()
        
        // Format date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        let dateText = dateFormatter.string(from: date)
        
        // Calculate appropriate font size based on video size
        let baseFontSize: CGFloat = min(size.width, size.height) * 0.06 // 6% of smaller dimension
        let fontSize = max(baseFontSize, 36) // Minimum 36pt
        
        // Create date attributes with shadow
        let shadow = NSShadow()
        shadow.shadowColor = UIColor.black.withAlphaComponent(0.5)
        shadow.shadowOffset = CGSize(width: 2, height: 2)
        shadow.shadowBlurRadius = 4
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9),
            .shadow: shadow
        ]
        
        // Calculate text size
        let textSize = dateText.size(withAttributes: attributes)
        
        // Position at top center with padding
        let padding: CGFloat = min(size.width, size.height) * 0.04 // 4% padding
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: padding,
            width: textSize.width,
            height: textSize.height
        )
        
        // Create a semi-transparent background for better visibility
        let backgroundRect = textRect.insetBy(dx: -padding/2, dy: -padding/4)
        context.setFillColor(UIColor.black.withAlphaComponent(0.3).cgColor)
        let cornerRadius: CGFloat = 6
        let path = UIBezierPath(roundedRect: backgroundRect, cornerRadius: cornerRadius)
        context.addPath(path.cgPath)
        context.fillPath()
        
        // Flip coordinate system for text drawing
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        // Draw the date text
        UIGraphicsPushContext(context)
        let flippedRect = CGRect(
            x: textRect.origin.x,
            y: textRect.origin.y,
            width: textRect.width,
            height: textRect.height
        )
        dateText.draw(in: flippedRect, withAttributes: attributes)
        UIGraphicsPopContext()
        
        // Restore context state
        context.restoreGState()
    }
    
    private func drawWeightChart(weightEntries: [WeightEntry], currentDate: Date, dateRange: ClosedRange<Date>, in context: CGContext, size: CGSize) {
        // Calculate chart size and position
        let chartHeight = size.height * 0.15 // 15% of video height
        let chartWidth = size.width * 0.9 // 90% of video width
        let chartX = (size.width - chartWidth) / 2
        let chartY: CGFloat = 10 // Position at top of the frame
        
        // Configure chart options
        let chartOptions = StaticWeightChartRenderer.ChartOptions(
            size: CGSize(width: chartWidth, height: chartHeight),
            showBodyFat: true,
            backgroundColor: UIColor.black.withAlphaComponent(0.8),
            gridColor: UIColor.white.withAlphaComponent(0.2),
            weightLineColor: UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0),
            bodyFatLineColor: UIColor(red: 1.0, green: 0.624, blue: 0.039, alpha: 1.0),
            progressBarColor: UIColor(red: 0.0, green: 0.8, blue: 0.0, alpha: 0.8),
            textColor: .white,
            font: .systemFont(ofSize: 12)
        )
        
        // Render the chart
        if let chartImage = StaticWeightChartRenderer.shared.renderChart(
            entries: weightEntries,
            currentDate: currentDate,
            dateRange: dateRange,
            options: chartOptions
        ) {
            // Draw chart with a semi-transparent background
            context.saveGState()
            
            // Add a rounded background
            let backgroundRect = CGRect(x: chartX - 10, y: chartY - 10, width: chartWidth + 20, height: chartHeight + 20)
            context.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
            let path = UIBezierPath(roundedRect: backgroundRect, cornerRadius: 10)
            context.addPath(path.cgPath)
            context.fillPath()
            
            // Draw the chart
            if let cgChart = chartImage.cgImage {
                context.draw(cgChart, in: CGRect(x: chartX, y: chartY, width: chartWidth, height: chartHeight))
            }
            
            // Add weight and body fat labels if available
            if let entry = weightEntries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: currentDate) }) {
                // Format weight
                let weightText = String(format: "%.1f kg", entry.weight)
                var bodyFatText = ""
                if let bodyFat = entry.bodyFatPercentage {
                    bodyFatText = String(format: " | %.1f%%", bodyFat)
                }
                let fullText = weightText + bodyFatText
                
                // Draw text below chart
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
                    .foregroundColor: UIColor.white
                ]
                
                let textSize = fullText.size(withAttributes: attributes)
                let textRect = CGRect(
                    x: (size.width - textSize.width) / 2,
                    y: chartY + chartHeight + 25,
                    width: textSize.width,
                    height: textSize.height
                )
                
                // Flip coordinate system for text drawing
                context.translateBy(x: 0, y: size.height)
                context.scaleBy(x: 1.0, y: -1.0)
                
                UIGraphicsPushContext(context)
                let flippedRect = CGRect(
                    x: textRect.origin.x,
                    y: size.height - textRect.origin.y - textRect.height,
                    width: textRect.width,
                    height: textRect.height
                )
                fullText.draw(in: flippedRect, withAttributes: attributes)
                UIGraphicsPopContext()
                
                // Restore coordinate system
                context.scaleBy(x: 1.0, y: -1.0)
                context.translateBy(x: 0, y: -size.height)
            }
            
            context.restoreGState()
        }
    }
    
    private func createSideBySidePixelBuffer(
        from categoryPhotos: [String: UIImage],
        categories: [String],
        size: CGSize,
        addWatermark: Bool,
        showDate: Bool = false,
        date: Date? = nil,
        showGraph: Bool = false,
        weightEntries: [WeightEntry]? = nil,
        dateRange: ClosedRange<Date>? = nil
    ) -> CVPixelBuffer? {
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
        
        // Calculate layout based on total selected categories (not just categories with photos)
        let totalCategories = categories.count
        
        // Calculate grid layout (max 2x2)
        let columns = min(totalCategories, 2)
        let rows = (totalCategories + 1) / 2
        
        // Reserve space for graph if needed
        let availableHeight = showGraph ? size.height * 0.75 : size.height
        let yOffset: CGFloat = showGraph ? size.height * 0.20 : 0
        
        let cellWidth = size.width / CGFloat(columns)
        let cellHeight = availableHeight / CGFloat(rows)
        
        // Draw each category slot (with or without photo)
        for (index, categoryId) in categories.enumerated() {
            let col = index % columns
            let row = index / columns
            
            let cellRect = CGRect(
                x: CGFloat(col) * cellWidth,
                y: yOffset + CGFloat(row) * cellHeight,
                width: cellWidth,
                height: cellHeight
            )
            
            if let image = categoryPhotos[categoryId] {
                // Fix orientation
                let orientedImage = image.fixedOrientation()
                
                // Calculate aspect fit rect within cell
                let imageSize = orientedImage.size
                let widthRatio = (cellWidth - 4) / imageSize.width  // 4pt padding
                let heightRatio = (cellHeight - 4) / imageSize.height
                let scale = min(widthRatio, heightRatio)
                
                let scaledSize = CGSize(
                    width: imageSize.width * scale,
                    height: imageSize.height * scale
                )
                
                let drawRect = CGRect(
                    x: cellRect.origin.x + (cellRect.width - scaledSize.width) / 2,
                    y: cellRect.origin.y + (cellRect.height - scaledSize.height) / 2,
                    width: scaledSize.width,
                    height: scaledSize.height
                )
                
                // Draw the image
                if let cgImage = orientedImage.cgImage {
                    context.draw(cgImage, in: drawRect)
                }
            } else {
                // Draw placeholder for missing photo
                drawNoPhotoPlaceholder(in: cellRect, context: context)
            }
            
            // Draw category label
            drawCategoryLabel(categoryId: categoryId, in: cellRect, context: context)
        }
        
        // Add divider lines
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(2)
        
        if columns > 1 {
            // Vertical divider
            context.move(to: CGPoint(x: cellWidth, y: yOffset))
            context.addLine(to: CGPoint(x: cellWidth, y: yOffset + availableHeight))
            context.strokePath()
        }
        
        if rows > 1 {
            // Horizontal divider
            context.move(to: CGPoint(x: 0, y: yOffset + cellHeight))
            context.addLine(to: CGPoint(x: size.width, y: yOffset + cellHeight))
            context.strokePath()
        }
        
        // Add date if needed
        if showDate, let date = date {
            drawDate(date, in: context, size: size)
        }
        
        // Add graph if needed (premium feature)
        if showGraph, let weightEntries = weightEntries, let dateRange = dateRange, let currentDate = date {
            drawWeightChart(weightEntries: weightEntries, currentDate: currentDate, dateRange: dateRange, in: context, size: size)
        }
        
        // Add watermark if needed
        if addWatermark {
            drawWatermark(in: context, size: size)
        }
        
        return buffer
    }
    
    private func drawCategoryLabel(categoryId: String, in rect: CGRect, context: CGContext) {
        // Get category name
        let categoryName = CategoryStorageService.shared.getCategoryById(categoryId)?.name ?? "Unknown"
        
        let fontSize: CGFloat = min(rect.width, rect.height) * 0.06
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: UIColor.white,
            .shadow: {
                let shadow = NSShadow()
                shadow.shadowColor = UIColor.black.withAlphaComponent(0.8)
                shadow.shadowOffset = CGSize(width: 1, height: 1)
                shadow.shadowBlurRadius = 3
                return shadow
            }()
        ]
        
        let textSize = categoryName.size(withAttributes: attributes)
        let padding: CGFloat = 8
        let textRect = CGRect(
            x: rect.origin.x + padding,
            y: rect.origin.y + padding,
            width: textSize.width,
            height: textSize.height
        )
        
        // Save context state
        context.saveGState()
        
        // Draw semi-transparent background
        let backgroundRect = textRect.insetBy(dx: -4, dy: -2)
        context.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
        let cornerRadius: CGFloat = 4
        let path = UIBezierPath(roundedRect: backgroundRect, cornerRadius: cornerRadius)
        context.addPath(path.cgPath)
        context.fillPath()
        
        // Flip coordinate system for text drawing
        context.translateBy(x: 0, y: rect.maxY * 2)
        context.scaleBy(x: 1.0, y: -1.0)
        
        // Draw the text
        UIGraphicsPushContext(context)
        let flippedRect = CGRect(
            x: textRect.origin.x,
            y: rect.maxY * 2 - textRect.maxY,
            width: textRect.width,
            height: textRect.height
        )
        categoryName.draw(in: flippedRect, withAttributes: attributes)
        UIGraphicsPopContext()
        
        // Restore context state
        context.restoreGState()
    }
    
    private func drawNoPhotoPlaceholder(in rect: CGRect, context: CGContext) {
        // Save context state
        context.saveGState()
        
        // Draw dark background with subtle border
        context.setFillColor(UIColor(white: 0.1, alpha: 1.0).cgColor)
        context.fill(rect.insetBy(dx: 2, dy: 2))
        
        // Draw border
        context.setStrokeColor(UIColor(white: 0.3, alpha: 0.5).cgColor)
        context.setLineWidth(1)
        context.stroke(rect.insetBy(dx: 2, dy: 2))
        
        // Draw "No Photo" text in center
        let noPhotoText = "video.no_photo".localized
        let fontSize = min(rect.width, rect.height) * 0.08
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: UIColor(white: 0.4, alpha: 1.0),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                return style
            }()
        ]
        
        let textSize = noPhotoText.size(withAttributes: attributes)
        let textRect = CGRect(
            x: rect.origin.x + (rect.width - textSize.width) / 2,
            y: rect.origin.y + (rect.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        // Flip coordinate system for text drawing
        context.translateBy(x: 0, y: rect.maxY * 2)
        context.scaleBy(x: 1.0, y: -1.0)
        
        // Draw the text
        UIGraphicsPushContext(context)
        let flippedRect = CGRect(
            x: textRect.origin.x,
            y: rect.maxY * 2 - textRect.maxY,
            width: textRect.width,
            height: textRect.height
        )
        noPhotoText.draw(in: flippedRect, withAttributes: attributes)
        UIGraphicsPopContext()
        
        // Restore context state
        context.restoreGState()
    }
}