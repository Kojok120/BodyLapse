import Foundation
import UIKit
import AVFoundation
import Photos

extension UIImage {
    func fixedOrientation() -> UIImage {
        // 方向が既に正しい場合は何もしない
        if imageOrientation == .up {
            return self
        }
        
        // 画像を正位にするための適切な変換を計算する必要がある
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
        
        // 基礎となるCGImageを新しいコンテキストに描画し、変換を適用
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
        
        // 描画コンテキストから新しいUIImageを作成
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
        let isWeightInLbs: Bool
        
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
            showGraph: false,
            isWeightInLbs: false
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
            
            // 日付範囲内の写真をフィルター
            let filteredPhotos: [Photo]
            
            if options.layout == .single || options.selectedCategories.isEmpty {
                // 単一カテゴリー動画 - 最初の選択カテゴリーまたは全写真でフィルター
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
                // サイドバイサイド動画 - 選択カテゴリーのみでフィルター
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
                    
                    // 動画をストレージに保存
                    let video = try await VideoStorageService.shared.saveVideo(
                        videoURL,
                        startDate: dateRange.lowerBound,
                        endDate: dateRange.upperBound,
                        frameCount: filteredPhotos.count
                    )
                    
                    // 一時ファイルをクリーンアップ
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
        
        // 既存のファイルを削除
        try? FileManager.default.removeItem(at: outputURL)
        
        // グラフが有効な場合、体重エントリを読み込み
        var weightEntries: [WeightEntry] = []
        var dateRange: ClosedRange<Date>? = nil
        
        if options.showGraph && !photos.isEmpty {
            // 写真から日付範囲を計算
            let sortedDates = photos.map { $0.captureDate }.sorted()
            if let startDate = sortedDates.first, let endDate = sortedDates.last {
                dateRange = startDate...endDate
                
                // 日付範囲の体重エントリを読み込み
                do {
                    weightEntries = try await WeightStorageService.shared.getEntries(
                        from: startDate,
                        to: endDate
                    )
                } catch {
                    // 読み込みに失敗しても体重データなしで続行
                    print("Failed to load weight entries: \(error)")
                }
            }
        }
        
        // ビデオライターを作成
        let videoWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        
        // ビデオ設定を構成
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
        
        // 書き込みを開始
        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: .zero)
        
        // 写真を処理
        var currentTime = CMTime.zero
        
        if options.layout == .single || options.selectedCategories.count <= 1 {
            // 単一カテゴリー動画の処理
            let totalPhotos = photos.count
            
            for (index, photo) in photos.enumerated() {
                guard let image = PhotoStorageService.shared.loadImage(for: photo) else { continue }
                
                // 有効な場合、顔のぼかしを適用
                let imageToProcess: UIImage
                if options.blurFaces {
                    let userSettings = await UserSettingsManager.shared
                    let blurMethod = await userSettings.settings.faceBlurMethod.toServiceMethod
                    imageToProcess = await FaceBlurService.shared.processImageAsync(image, blurMethod: blurMethod)
                } else {
                    imageToProcess = image
                }
                
                // ピクセルバッファに変換
                if let pixelBuffer = autoreleasepool(invoking: { () -> CVPixelBuffer? in
                    createPixelBuffer(
                        from: imageToProcess,
                        size: options.videoSize,
                        addWatermark: options.addWatermark,
                        showDate: options.showDate,
                        date: photo.captureDate,
                        showGraph: options.showGraph,
                        weightEntries: weightEntries,
                        dateRange: dateRange,
                        isWeightInLbs: options.isWeightInLbs
                    )
                }) {
                    // 非同期で入力の準備ができるまで待機
                    while !videoWriterInput.isReadyForMoreMediaData {
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    }
                    
                    // ピクセルバッファを追加
                    pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: currentTime)
                    currentTime = CMTimeAdd(currentTime, options.frameDuration)
                }
                
                // 進捗を更新
                let progressValue = Float(index + 1) / Float(totalPhotos)
                await MainActor.run {
                    progress(progressValue)
                }
            }
        } else {
            // サイドバイサイド動画の処理
            // 写真は既に選択カテゴリーでフィルター済み
            let photosByDate = Dictionary(grouping: photos) { photo in
                Calendar.current.startOfDay(for: photo.captureDate)
            }
            
            let sortedDates = photosByDate.keys.sorted()
            let totalFrames = sortedDates.count
            
            for (index, date) in sortedDates.enumerated() {
                let photosForDate = photosByDate[date] ?? []
                
                // 各選択カテゴリーの写真を取得
                var categoryPhotos: [String: UIImage] = [:]
                for categoryId in options.selectedCategories {
                    if let photo = photosForDate.first(where: { $0.categoryId == categoryId }),
                       let image = PhotoStorageService.shared.loadImage(for: photo) {
                        // 有効な場合、顔のぼかしを適用
                        if options.blurFaces {
                            let userSettings = await UserSettingsManager.shared
                            let blurMethod = await userSettings.settings.faceBlurMethod.toServiceMethod
                            categoryPhotos[categoryId] = await FaceBlurService.shared.processImageAsync(image, blurMethod: blurMethod)
                        } else {
                            categoryPhotos[categoryId] = image
                        }
                    }
                }
                
                // 少なくとも1枚の写真がある場合のみフレームを作成
                if !categoryPhotos.isEmpty {
                    // ピクセルバッファに変換
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
                            dateRange: dateRange,
                            isWeightInLbs: options.isWeightInLbs
                        )
                    }) {
                        // 非同期で入力の準備ができるまで待機
                        while !videoWriterInput.isReadyForMoreMediaData {
                            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                        }
                        
                        // ピクセルバッファを追加
                        pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: currentTime)
                        currentTime = CMTimeAdd(currentTime, options.frameDuration)
                    }
                }
                
                // 進捗を更新
                let progressValue = Float(index + 1) / Float(totalFrames)
                await MainActor.run {
                    progress(progressValue)
                }
            }
        }
        
        // 書き込みを完了
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
    
    
    
    private func createPixelBuffer(from image: UIImage, size: CGSize, addWatermark: Bool, showDate: Bool = false, date: Date? = nil, showGraph: Bool = false, weightEntries: [WeightEntry]? = nil, dateRange: ClosedRange<Date>? = nil, isWeightInLbs: Bool = false) -> CVPixelBuffer? {
        // 必要に応じて方向を修正
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
        
        // 背景を黒で塗りつぶす
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        // アスペクトフィットの矩形を計算
        let imageSize = orientedImage.size
        
        // グラフが必要な場合、スペースを予約
        let availableHeight = showGraph ? size.height * 0.75 : size.height // Reserve 25% for graph
        let availableSize = CGSize(width: size.width, height: availableHeight)
        
        let widthRatio = availableSize.width / imageSize.width
        let heightRatio = availableSize.height / imageSize.height
        let scale = min(widthRatio, heightRatio)
        
        let scaledSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        
        // グラフ表示時は画像を下部に配置
        let yOffset = showGraph ? size.height * 0.20 : (size.height - scaledSize.height) / 2
        let drawRect = CGRect(
            x: (size.width - scaledSize.width) / 2,
            y: yOffset,
            width: scaledSize.width,
            height: scaledSize.height
        )
        
        // 画像を描画
        if let cgImage = orientedImage.cgImage {
            context.draw(cgImage, in: drawRect)
        }
        
        // Add date if needed
        if showDate, let date = date {
            drawDate(date, in: context, size: size)
        }
        
        // Add graph if needed (premium feature)
        if showGraph, let weightEntries = weightEntries, let dateRange = dateRange, let currentDate = date {
            drawWeightChart(weightEntries: weightEntries, currentDate: currentDate, dateRange: dateRange, in: context, size: size, isWeightInLbs: isWeightInLbs)
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
        // Increase top padding to avoid overlap with image
        let padding: CGFloat = min(size.width, size.height) * 0.00 // 8% padding (increased from 4%)
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
    
    private func drawWeightChart(weightEntries: [WeightEntry], currentDate: Date, dateRange: ClosedRange<Date>, in context: CGContext, size: CGSize, isWeightInLbs: Bool) {
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
            font: .systemFont(ofSize: 12),
            isWeightInLbs: isWeightInLbs
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
                // Format weight with correct unit
                let convertedWeight = isWeightInLbs ? entry.weight * 2.20462 : entry.weight
                let weightUnit = isWeightInLbs ? "lbs" : "kg"
                let weightText = String(format: "%.1f %@", convertedWeight, weightUnit)
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
        dateRange: ClosedRange<Date>? = nil,
        isWeightInLbs: Bool = false
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
        
        // 全選択カテゴリー数に基づいてレイアウトを計算（写真があるカテゴリーだけでなく）
        let totalCategories = categories.count
        
        // グリッドレイアウトを計算（最大2x2）
        let columns = min(totalCategories, 2)
        let rows = (totalCategories + 1) / 2
        
        // グラフが必要な場合、スペースを予約
        let availableHeight = showGraph ? size.height * 0.75 : size.height
        let yOffset: CGFloat = showGraph ? size.height * 0.20 : 0
        
        let cellWidth = size.width / CGFloat(columns)
        let cellHeight = availableHeight / CGFloat(rows)
        
        // 各カテゴリースロットを描画（写真の有無に関わらず）
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
                // 方向を修正
                let orientedImage = image.fixedOrientation()
                
                // セル内のアスペクトフィット矩形を計算
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
                
                // 画像を描画
                if let cgImage = orientedImage.cgImage {
                    context.draw(cgImage, in: drawRect)
                }
            } else {
                // 写真がない場合のプレースホルダーを描画
                drawNoPhotoPlaceholder(in: cellRect, context: context)
            }
            
            // カテゴリーラベルを描画
            drawCategoryLabel(categoryId: categoryId, in: cellRect, context: context)
        }
        
        // 分割線を追加
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(2)
        
        if columns > 1 {
            // 垂直分割線
            context.move(to: CGPoint(x: cellWidth, y: yOffset))
            context.addLine(to: CGPoint(x: cellWidth, y: yOffset + availableHeight))
            context.strokePath()
        }
        
        if rows > 1 {
            // 水平分割線
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
            drawWeightChart(weightEntries: weightEntries, currentDate: currentDate, dateRange: dateRange, in: context, size: size, isWeightInLbs: isWeightInLbs)
        }
        
        // Add watermark if needed
        if addWatermark {
            drawWatermark(in: context, size: size)
        }
        
        return buffer
    }
    
    private func drawCategoryLabel(categoryId: String, in rect: CGRect, context: CGContext) {
        // カテゴリー名を取得
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