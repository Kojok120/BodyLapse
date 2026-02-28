import SwiftUI
import Vision
import CoreImage
#if os(iOS)
import UIKit
#endif

class BodyContourService {
    static let shared = BodyContourService()
    
    private init() {}

    #if DEBUG
    private var isDebugMaskSavingEnabled: Bool {
        ProcessInfo.processInfo.environment["BODYLAPSE_SAVE_DEBUG_MASKS"] == "1" ||
        UserDefaults.standard.bool(forKey: "BODYLAPSE_SAVE_DEBUG_MASKS")
    }
    #endif
    
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
        
        if #available(iOS 17.0, *) {
            // iOS 17以降では新しいフォアグラウンドインスタンスマスクを使用
            let request = VNGenerateForegroundInstanceMaskRequest { [weak self] request, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let observation = request.results?.first else {
                    DispatchQueue.main.async {
                        completion(.failure(ContourError.noPersonDetected))
                    }
                    return
                }
                
                // 元画像用のハンドラーを作成
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                
                // フォアグラウンドマスクから輪郭を抽出
                self?.extractContourFromForegroundMask(observation: observation, handler: handler, imageSize: CGSize(width: cgImage.width, height: cgImage.height), originalImage: image) { result in
                    DispatchQueue.main.async {
                        completion(result)
                    }
                }
            }
            
            // リクエストを実行
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
        } else {
            // 古いiOSバージョンではサリエンシー検出にフォールバック
            let request = VNGenerateAttentionBasedSaliencyImageRequest { [weak self] request, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let observation = request.results?.first as? VNSaliencyImageObservation else {
                    DispatchQueue.main.async {
                        completion(.failure(ContourError.noPersonDetected))
                    }
                    return
                }
                
                // サリエンシーヒートマップから輪郭を抽出
                self?.extractContourFromSaliency(observation: observation, imageSize: CGSize(width: cgImage.width, height: cgImage.height)) { result in
                    DispatchQueue.main.async {
                        completion(result)
                    }
                }
            }
            
            // リクエストを実行
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
    }
    
    @available(iOS 17.0, *)
    private func extractContourFromForegroundMask(observation: VNObservation, handler: VNImageRequestHandler, imageSize: CGSize, originalImage: UIImage, completion: @escaping (Result<[CGPoint], Error>) -> Void) {
        guard let instanceMask = observation as? VNInstanceMaskObservation else {
            completion(.failure(ContourError.imageProcessingFailed))
            return
        }
        
        // 全インスタンスを取得
        let instances = instanceMask.allInstances
        guard !instances.isEmpty else {
            completion(.failure(ContourError.noPersonDetected))
            return
        }
        
        // 最初のインスタンスを使用（通常最も目立つもの）
        guard let firstInstance = instances.first else {
            completion(.failure(ContourError.noPersonDetected))
            return
        }
        
        print("Detected \(instances.count) instances, using instance: \(firstInstance)")
        
        // 特定のインスタンス用のマスクを生成
        do {
            // 選択したインスタンス用のスケーリングマスクを生成
            let maskedPixelBuffer = try instanceMask.generateScaledMaskForImage(
                forInstances: IndexSet(integer: firstInstance),
                from: handler
            )
            
            // デバッグ: マスク情報を出力
            let maskWidth = CVPixelBufferGetWidth(maskedPixelBuffer)
            let maskHeight = CVPixelBufferGetHeight(maskedPixelBuffer)
            print("Mask size: \(maskWidth)x\(maskHeight)")
            
            #if DEBUG
            if isDebugMaskSavingEnabled {
                debugSaveMask(pixelBuffer: maskedPixelBuffer)
            }
            #endif
            
            // マスクをUIImageに変換
            let ciImage = CIImage(cvPixelBuffer: maskedPixelBuffer)
            let context = CIContext()
            
            if let cgMask = context.createCGImage(ciImage, from: ciImage.extent) {
                let maskImage = UIImage(cgImage: cgMask)
                
                // OpenCVを使用してより良い輪郭抽出を行う
                if let cgImage = originalImage.cgImage {
                    // 実際の画像サイズを取得
                    let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
                    
                    let contourPoints = OpenCVWrapper.processContour(from: originalImage, withMaskImage: maskImage)
                    
                    // NSArray<NSValue>を[CGPoint]に変換
                    var points: [CGPoint] = []
                    for value in contourPoints {
                        points.append(value.cgPointValue)
                    }
                    
                    if points.isEmpty {
                        // 元の方法にフォールバック
                        extractContourFromMask(pixelBuffer: maskedPixelBuffer, imageSize: imageSize, completion: completion)
                    } else {
                        // デバッグログ
                        print("OpenCV returned \(points.count) points")
                        if let firstPoint = points.first, let lastPoint = points.last {
                            print("First point: \(firstPoint), Last point: \(lastPoint)")
                            print("Image size from cgImage: \(imageSize)")
                        }
                        completion(.success(points))
                    }
                } else {
                    // 元の方法にフォールバック
                    extractContourFromMask(pixelBuffer: maskedPixelBuffer, imageSize: imageSize, completion: completion)
                }
            } else {
                // 元の方法にフォールバック
                extractContourFromMask(pixelBuffer: maskedPixelBuffer, imageSize: imageSize, completion: completion)
            }
        } catch {
            print("Failed to generate scaled mask: \(error)")
            // マスク画像の生成を代わりに試行
            do {
                let maskedImage = try instanceMask.generateMaskedImage(
                    ofInstances: IndexSet(integer: firstInstance),
                    from: handler,
                    croppedToInstancesExtent: false
                )
                
                print("Using masked image fallback")
                
                // マスク画像から輪郭を抽出
                extractContourFromMask(pixelBuffer: maskedImage, imageSize: imageSize, completion: completion)
            } catch {
                print("Failed to generate masked image: \(error)")
                completion(.failure(ContourError.imageProcessingFailed))
            }
        }
    }
    
    #if DEBUG
    private func debugSaveMask(pixelBuffer: CVPixelBuffer) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let uiImage = UIImage(cgImage: cgImage)
            
            if let data = uiImage.pngData() {
                let tempDir = FileManager.default.temporaryDirectory
                let tempURL = tempDir.appendingPathComponent("vision_mask_\(Date().timeIntervalSince1970).png")
                try? data.write(to: tempURL)
                print("Debug mask saved to tmp: \(tempURL.path)")
            }
        }
    }
    #endif
    
    private func extractContourFromMask(pixelBuffer: CVPixelBuffer, imageSize: CGSize, completion: @escaping (Result<[CGPoint], Error>) -> Void) {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // ピクセルフォーマットを確認
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        print("Pixel format: \(pixelFormat)")
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            completion(.failure(ContourError.imageProcessingFailed))
            return
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        // floatフォーマットか確認
        let isFloatFormat = pixelFormat == kCVPixelFormatType_DepthFloat32
        
        if isFloatFormat {
            // floatピクセルフォーマットを処理
            extractContourFromFloatMask(baseAddress: baseAddress, width: width, height: height, bytesPerRow: bytesPerRow, imageSize: imageSize, completion: completion)
        } else {
            // byteピクセルフォーマットを処理
            let pixelData = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        // デバッグ: ピクセル値の範囲を確認
        var minPixelValue: UInt8 = 255
        var maxPixelValue: UInt8 = 0
        var foregroundPixelCount = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * bytesPerRow + x
                let pixelValue = pixelData[pixelIndex]
                minPixelValue = min(minPixelValue, pixelValue)
                maxPixelValue = max(maxPixelValue, pixelValue)
                if pixelValue > 0 {
                    foregroundPixelCount += 1
                }
            }
        }
        
        print("Pixel value range: \(minPixelValue) - \(maxPixelValue)")
        print("Foreground pixels: \(foregroundPixelCount) out of \(width * height)")
        
        // ピクセル値の範囲に基づいて閾値を決定
        let threshold: UInt8 = maxPixelValue > 1 ? maxPixelValue / 2 : 0
        print("Using threshold: \(threshold)")
        
        // ステップ1: 全エッジピクセルを検出
        var edgePixels: [(x: Int, y: Int)] = []
        
        // 画像をスキャンしてエッジピクセルを検出
        for y in 1..<height-1 {
            for x in 1..<width-1 {
                let pixelIndex = y * bytesPerRow + x
                let currentPixel = pixelData[pixelIndex]
                
                if currentPixel > threshold {
                    // このピクセルがエッジピクセルか確認（背景の隣接ピクセルが少なくとも1つあるか）
                    var hasBackgroundNeighbor = false
                    
                    // 8方向の隣接ピクセルを確認
                    let neighbors = [
                        (-1, -1), (0, -1), (1, -1),
                        (-1, 0),            (1, 0),
                        (-1, 1),  (0, 1),   (1, 1)
                    ]
                    
                    for (dx, dy) in neighbors {
                        let nx = x + dx
                        let ny = y + dy
                        if nx >= 0 && nx < width && ny >= 0 && ny < height {
                            let neighborIndex = ny * bytesPerRow + nx
                            if pixelData[neighborIndex] <= threshold {
                                hasBackgroundNeighbor = true
                                break
                            }
                        } else {
                            // 画像境界は背景とみなす
                            hasBackgroundNeighbor = true
                            break
                        }
                    }
                    
                    if hasBackgroundNeighbor {
                        edgePixels.append((x: x, y: y))
                    }
                }
            }
        }
        
        print("Found \(edgePixels.count) edge pixels")
        
        // ステップ2: チェインコードで外側輪郭をトレース
        guard !edgePixels.isEmpty else {
            completion(.failure(ContourError.noPersonDetected))
            return
        }
        
        // 高速検索用のエッジマップを作成
        var edgeMap = [[Bool]](repeating: [Bool](repeating: false, count: width), count: height)
        for edge in edgePixels {
            edgeMap[edge.y][edge.x] = true
        }
        
        // 開始点を検出（最上部、次に最左）
        guard let startPoint = edgePixels.min(by: { a, b in
            if a.y != b.y { return a.y < b.y }
            return a.x < b.x
        }) else {
            completion(.failure(ContourError.noPersonDetected))
            return
        }
        
        // Moore近傍トレースで輪郭をトレース
        var contourPoints: [CGPoint] = []
        var current = startPoint
        var visited = Set<String>()
        
        // 方向コード: 0=E, 1=SE, 2=S, 3=SW, 4=W, 5=NW, 6=N, 7=NE
        let directions = [(1,0), (1,1), (0,1), (-1,1), (-1,0), (-1,-1), (0,-1), (1,-1)]
        var dir = 0 // 開始方向
        
        let maxSteps = edgePixels.count * 2
        var steps = 0
        
        repeat {
            // 現在のポイントを輪郭に追加
            let scaledX = CGFloat(current.x) * imageSize.width / CGFloat(width)
            let scaledY = CGFloat(current.y) * imageSize.height / CGFloat(height)
            contourPoints.append(CGPoint(x: scaledX, y: scaledY))
            
            let key = "\(current.x),\(current.y)"
            visited.insert(key)
            
            // 次のポイントを検出
            var found = false
            let startDir = (dir + 5) % 8 // 反時計回りに90度から探索開始
            
            for i in 0..<8 {
                let searchDir = (startDir + i) % 8
                let dx = directions[searchDir].0
                let dy = directions[searchDir].1
                let nx = current.x + dx
                let ny = current.y + dy
                
                if nx >= 0 && nx < width && ny >= 0 && ny < height && edgeMap[ny][nx] {
                    current = (x: nx, y: ny)
                    dir = searchDir
                    found = true
                    break
                }
            }
            
            steps += 1
            
            // 停止条件
            if !found || steps >= maxSteps {
                break
            }
            
            // 開始点に戻ったか確認
            if current.x == startPoint.x && current.y == startPoint.y && steps > 8 {
                break
            }
            
        } while true
        
        print("Traced contour with \(contourPoints.count) points")
        
        // 輪郭トレースがうまくいかなかった場合、全エッジピクセルを使用
        if contourPoints.count < 50 {
            print("Contour tracing produced too few points, using all edge pixels")
            contourPoints = []
            for edge in edgePixels {
                let scaledX = CGFloat(edge.x) * imageSize.width / CGFloat(width)
                let scaledY = CGFloat(edge.y) * imageSize.height / CGFloat(height)
                contourPoints.append(CGPoint(x: scaledX, y: scaledY))
            }
        }
        
        guard !contourPoints.isEmpty else {
            completion(.failure(ContourError.noPersonDetected))
            return
        }
        
        // ステップ3: 輪郭を順序付けるためにエッジポイントを角度でソート
        // 全エッジピクセルの中心点を検出
        let centerX = contourPoints.reduce(0) { $0 + $1.x } / CGFloat(contourPoints.count)
        let centerY = contourPoints.reduce(0) { $0 + $1.y } / CGFloat(contourPoints.count)
        
        // 中心からの角度でポイントをソート
        let sortedContour = contourPoints.sorted { point1, point2 in
            let angle1 = atan2(point1.y - centerY, point1.x - centerX)
            let angle2 = atan2(point2.y - centerY, point2.x - centerX)
            return angle1 < angle2
        }
        
        // 多すぎる場合はポイントをサンプリング
        var finalContour = sortedContour
        if sortedContour.count > 500 {
            let step = sortedContour.count / 360
            finalContour = []
            for i in stride(from: 0, to: sortedContour.count, by: step) {
                finalContour.append(sortedContour[i])
            }
        }
        
        print("Sorted contour has \(finalContour.count) points")
        print("Final contour has \(finalContour.count) points")
        
        // ステップ4: スムージングを適用
        let smoothedContour = smoothContourAggressive(finalContour)
        completion(.success(smoothedContour))
        }
    }
    
    private func extractContourFromFloatMask(baseAddress: UnsafeRawPointer, width: Int, height: Int, bytesPerRow: Int, imageSize: CGSize, completion: @escaping (Result<[CGPoint], Error>) -> Void) {
        let pixelData = baseAddress.assumingMemoryBound(to: Float32.self)
        
        // デバッグ: ピクセル値の範囲を確認
        var minPixelValue: Float32 = Float.infinity
        var maxPixelValue: Float32 = -Float.infinity
        var foregroundPixelCount = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * bytesPerRow / MemoryLayout<Float32>.size) + x
                let pixelValue = pixelData[pixelIndex]
                minPixelValue = min(minPixelValue, pixelValue)
                maxPixelValue = max(maxPixelValue, pixelValue)
                if pixelValue > 0 {
                    foregroundPixelCount += 1
                }
            }
        }
        
        print("Float pixel value range: \(minPixelValue) - \(maxPixelValue)")
        print("Foreground pixels: \(foregroundPixelCount) out of \(width * height)")
        
        // ピクセル値の範囲に基づいて閾値を決定
        let threshold: Float32 = maxPixelValue > 0 ? maxPixelValue * 0.5 : 0
        print("Using float threshold: \(threshold)")
        
        // エッジピクセルを検出
        var edgePixels: [(x: Int, y: Int)] = []
        
        for y in 1..<height-1 {
            for x in 1..<width-1 {
                let pixelIndex = (y * bytesPerRow / MemoryLayout<Float32>.size) + x
                let currentPixel = pixelData[pixelIndex]
                
                if currentPixel > threshold {
                    var hasBackgroundNeighbor = false
                    
                    for dy in -1...1 {
                        for dx in -1...1 {
                            if dx == 0 && dy == 0 { continue }
                            
                            let nx = x + dx
                            let ny = y + dy
                            if nx >= 0 && nx < width && ny >= 0 && ny < height {
                                let neighborIndex = (ny * bytesPerRow / MemoryLayout<Float32>.size) + nx
                                if pixelData[neighborIndex] <= threshold {
                                    hasBackgroundNeighbor = true
                                    break
                                }
                            }
                        }
                        if hasBackgroundNeighbor { break }
                    }
                    
                    if hasBackgroundNeighbor {
                        edgePixels.append((x: x, y: y))
                    }
                }
            }
        }
        
        print("Found \(edgePixels.count) edge pixels from float mask")
        
        guard !edgePixels.isEmpty else {
            completion(.failure(ContourError.noPersonDetected))
            return
        }
        
        // エッジピクセルを輪郭ポイントに変換
        var contourPoints: [CGPoint] = []
        for edge in edgePixels {
            let scaledX = CGFloat(edge.x) * imageSize.width / CGFloat(width)
            let scaledY = CGFloat(edge.y) * imageSize.height / CGFloat(height)
            contourPoints.append(CGPoint(x: scaledX, y: scaledY))
        }
        
        // 中心からの角度でソートして順序を改善
        let centerX = imageSize.width / 2
        let centerY = imageSize.height / 2
        
        contourPoints.sort { point1, point2 in
            let angle1 = atan2(point1.y - centerY, point1.x - centerX)
            let angle2 = atan2(point2.y - centerY, point2.x - centerX)
            return angle1 < angle2
        }
        
        let smoothedContour = smoothContourAggressive(contourPoints)
        completion(.success(smoothedContour))
    }
    
    private func extractContourFromSaliency(observation: VNSaliencyImageObservation, imageSize: CGSize, completion: @escaping (Result<[CGPoint], Error>) -> Void) {
        let pixelBuffer = observation.pixelBuffer
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            completion(.failure(ContourError.imageProcessingFailed))
            return
        }
        
        // サリエンシーマップをバイナリマスクに変換
        // グレースケールのサリエンシーをバイナリに変換するための閾値フィルターを作成
        guard let thresholdFilter = CIFilter(name: "CIColorMonochrome") else {
            completion(.failure(ContourError.imageProcessingFailed))
            return
        }
        
        thresholdFilter.setValue(ciImage, forKey: kCIInputImageKey)
        thresholdFilter.setValue(CIColor(red: 1, green: 1, blue: 1), forKey: "inputColor")
        thresholdFilter.setValue(0.3, forKey: "inputIntensity") // 必要に応じて閾値を調整
        
        guard let outputImage = thresholdFilter.outputImage,
              let binaryImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            completion(.failure(ContourError.imageProcessingFailed))
            return
        }
        
        // バイナリ画像から輪郭ポイントを抽出
        var contourPoints = extractBoundaryPoints(from: binaryImage, originalSize: imageSize)
        
        // 十分なポイントがない場合、別のアプローチを試行
        if contourPoints.count < 20 {
            contourPoints = extractContourUsingEdgeDetection(from: cgImage, originalSize: imageSize)
        }
        
        completion(.success(contourPoints))
    }
    
    private func extractBoundaryPoints(from cgImage: CGImage, originalSize: CGSize) -> [CGPoint] {
        let width = cgImage.width
        let height = cgImage.height
        
        // ピクセルデータを取得
        guard let data = cgImage.dataProvider?.data,
              let pixels = CFDataGetBytePtr(data) else {
            return []
        }
        
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        
        var boundaryPoints: [CGPoint] = []
        
        // 複数方向からスキャンして境界を検出
        let scanAngles = stride(from: 0, to: 360, by: 5)
        let centerX = CGFloat(width) / 2
        let centerY = CGFloat(height) / 2
        
        for angle in scanAngles {
            let radians = CGFloat(angle) * .pi / 180
            let maxRadius = min(centerX, centerY) * 1.5
            
            // 中心から外側にスキャン
            for radius in stride(from: 0, to: maxRadius, by: 2) {
                let x = Int(centerX + radius * cos(radians))
                let y = Int(centerY + radius * sin(radians))
                
                if x >= 0 && x < width && y >= 0 && y < height {
                    let pixelIndex = y * bytesPerRow + x * bytesPerPixel
                    let pixelValue = pixels[pixelIndex]
                    
                    // サリエンシーマップで特徴的なピクセル（明るい）か確認
                    if pixelValue > 100 {
                        // 元の画像サイズにスケーリング
                        let scaledX = CGFloat(x) * originalSize.width / CGFloat(width)
                        let scaledY = CGFloat(y) * originalSize.height / CGFloat(height)
                        boundaryPoints.append(CGPoint(x: scaledX, y: scaledY))
                        break
                    }
                }
            }
        }
        
        return smoothContour(boundaryPoints)
    }
    
    private func extractContourUsingEdgeDetection(from cgImage: CGImage, originalSize: CGSize) -> [CGPoint] {
        // エッジ検出を使用した代替アプローチ
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext()
        
        // エッジ検出を適用
        guard let edgeFilter = CIFilter(name: "CIEdges") else {
            return []
        }
        
        edgeFilter.setValue(ciImage, forKey: kCIInputImageKey)
        edgeFilter.setValue(5.0, forKey: "inputIntensity")
        
        guard let outputImage = edgeFilter.outputImage,
              let edgeImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return []
        }
        
        return extractBoundaryPoints(from: edgeImage, originalSize: originalSize)
    }
    
    private func extractContour(from pixelBuffer: CVPixelBuffer, imageSize: CGSize, completion: @escaping (Result<[CGPoint], Error>) -> Void) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard context.createCGImage(ciImage, from: ciImage.extent) != nil else {
            completion(.failure(ContourError.imageProcessingFailed))
            return
        }
        
        // バイナリ画像に変換して輪郭を検出
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        print("Extracting contour from mask of size: \(width)x\(height)")
        
        // エッジ検出アプローチ - アウトラインをトレース
        
        // 上から開始点を検出
        var startPoint: CGPoint?
        for y in 0..<height {
            for x in 0..<width {
                if isPersonPixel(at: CGPoint(x: CGFloat(x), y: CGFloat(y)), in: pixelBuffer) {
                    startPoint = CGPoint(x: CGFloat(x), y: CGFloat(y))
                    break
                }
            }
            if startPoint != nil { break }
        }
        
        guard let start = startPoint else {
            print("No person pixels found in mask")
            completion(.failure(ContourError.noPersonDetected))
            return
        }
        
        // エッジ追跡アルゴリズムでアウトラインをトレース
        var visited = Set<String>()
        var current = start
        let directions = [
            CGPoint(x: 0, y: -1),   // up
            CGPoint(x: 1, y: -1),   // up-right
            CGPoint(x: 1, y: 0),    // right
            CGPoint(x: 1, y: 1),    // down-right
            CGPoint(x: 0, y: 1),    // down
            CGPoint(x: -1, y: 1),   // down-left
            CGPoint(x: -1, y: 0),   // left
            CGPoint(x: -1, y: -1)   // up-left
        ]
        
        // エッジをトレース
        var edgePoints: [CGPoint] = []
        var lastDirection = 0
        
        repeat {
            let key = "\(Int(current.x)),\(Int(current.y))"
            if visited.contains(key) && edgePoints.count > 20 {
                break
            }
            visited.insert(key)
            
            // このポイントがエッジポイントか確認（非人物の隣接ピクセルが少なくとも1つあるか）
            var isEdge = false
            for dir in directions {
                let neighbor = CGPoint(x: current.x + dir.x, y: current.y + dir.y)
                if neighbor.x >= 0 && neighbor.x < CGFloat(width) && neighbor.y >= 0 && neighbor.y < CGFloat(height) {
                    if !isPersonPixel(at: neighbor, in: pixelBuffer) {
                        isEdge = true
                        break
                    }
                }
            }
            
            if isEdge {
                edgePoints.append(current)
            }
            
            // 次のエッジポイントを検出
            var foundNext = false
            for i in 0..<directions.count {
                let dirIndex = (lastDirection + i) % directions.count
                let dir = directions[dirIndex]
                let next = CGPoint(x: current.x + dir.x, y: current.y + dir.y)
                
                if next.x >= 0 && next.x < CGFloat(width) && next.y >= 0 && next.y < CGFloat(height) {
                    if isPersonPixel(at: next, in: pixelBuffer) {
                        var hasNonPersonNeighbor = false
                        for checkDir in directions {
                            let checkPoint = CGPoint(x: next.x + checkDir.x, y: next.y + checkDir.y)
                            if checkPoint.x >= 0 && checkPoint.x < CGFloat(width) && checkPoint.y >= 0 && checkPoint.y < CGFloat(height) {
                                if !isPersonPixel(at: checkPoint, in: pixelBuffer) {
                                    hasNonPersonNeighbor = true
                                    break
                                }
                            }
                        }
                        
                        if hasNonPersonNeighbor {
                            current = next
                            lastDirection = dirIndex
                            foundNext = true
                            break
                        }
                    }
                }
            }
            
            if !foundNext || edgePoints.count > 1000 {
                break
            }
            
        } while edgePoints.count < 1000
        
        print("Found \(edgePoints.count) edge points")
        
        // エッジポイントをサンプリングして密度を下げる
        let targetPoints = 72  // 5度ごとに1ポイント
        let step = max(1, edgePoints.count / targetPoints)
        var sampledPoints: [CGPoint] = []
        
        for i in stride(from: 0, to: edgePoints.count, by: step) {
            let point = edgePoints[i]
            // 元の画像サイズにスケーリング
            let scaledX = point.x * imageSize.width / CGFloat(width)
            let scaledY = point.y * imageSize.height / CGFloat(height)
            sampledPoints.append(CGPoint(x: scaledX, y: scaledY))
        }
        
        print("Sampled to \(sampledPoints.count) contour points")
        
        // 輪郭をスムージング
        let smoothedContour = smoothContour(sampledPoints)
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
        
        // Visionフレームワークの人物セグメンテーションは信頼度値を使用
        // 値が高いほどそのピクセルが人物に属する信頼度が高い
        let pixelValue = pixel[offset]
        
        // より良い検出のために低い閾値を使用
        return pixelValue > 50
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
    
    private func smoothContourAggressive(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count > 5 else { return points }
        
        // 第1パス: 基本スムージング
        let smoothed = smoothContour(points)
        
        // 第2パス: より大きなウィンドウでガウシアン風スムージングを適用
        let windowSize = 5
        var finalSmoothed: [CGPoint] = []
        
        for i in 0..<smoothed.count {
            var sumX: CGFloat = 0
            var sumY: CGFloat = 0
            var totalWeight: CGFloat = 0
            
            for j in -windowSize...windowSize {
                let index = (i + j + smoothed.count) % smoothed.count
                // ガウシアン風の重み付け - 近いポイントほど影響が大きい
                let weight = exp(-pow(CGFloat(j), 2) / (2 * pow(CGFloat(windowSize) / 2, 2)))
                sumX += smoothed[index].x * weight
                sumY += smoothed[index].y * weight
                totalWeight += weight
            }
            
            finalSmoothed.append(CGPoint(x: sumX / totalWeight, y: sumY / totalWeight))
        }
        
        // 第3パス: 外れ値を除去して再スムージング
        var filtered: [CGPoint] = []
        let maxDistanceRatio: CGFloat = 2.0
        
        for i in 0..<finalSmoothed.count {
            let prev = finalSmoothed[(i - 1 + finalSmoothed.count) % finalSmoothed.count]
            let current = finalSmoothed[i]
            let next = finalSmoothed[(i + 1) % finalSmoothed.count]
            
            let avgDistance = (distance(from: prev, to: current) + distance(from: current, to: next)) / 2
            let centerPoint = CGPoint(x: (prev.x + next.x) / 2, y: (prev.y + next.y) / 2)
            let deviationDistance = distance(from: current, to: centerPoint)
            
            if deviationDistance < avgDistance * maxDistanceRatio {
                filtered.append(current)
            } else {
                // 外れ値を補間ポイントで置換
                filtered.append(centerPoint)
            }
        }
        
        // 最終スムージングパス
        return smoothContour(filtered)
    }
    
    private func distance(from point1: CGPoint, to point2: CGPoint) -> CGFloat {
        return sqrt(pow(point1.x - point2.x, 2) + pow(point1.y - point2.y, 2))
    }
    
    // Grahamスキャンアルゴリズムによる凸包
    private func convexHull(points: [CGPoint]) -> [CGPoint] {
        guard points.count >= 3 else { return points }
        
        // 最も低y座標のポイントを検出（同じ場合は最左）
        guard let start = points.min(by: { a, b in
            if a.y != b.y { return a.y < b.y }
            return a.x < b.x
        }) else { return points }
        
        // 開始点からの極角度でポイントをソート
        let sortedPoints = points.filter { $0 != start }.sorted { a, b in
            let angleA = atan2(a.y - start.y, a.x - start.x)
            let angleB = atan2(b.y - start.y, b.x - start.x)
            if angleA != angleB { return angleA < angleB }
            // 角度が等しい場合、近いポイントを先に
            let distA = distance(from: start, to: a)
            let distB = distance(from: start, to: b)
            return distA < distB
        }
        
        // 凸包を構築
        var hull = [start]
        
        for point in sortedPoints {
            // 時計回りのターンを作るポイントを除去
            while hull.count > 1 && crossProduct(hull[hull.count-2], hull[hull.count-1], point) <= 0 {
                hull.removeLast()
            }
            hull.append(point)
        }
        
        return hull
    }
    
    // ベクトル(p1->p2)と(p1->p3)の外積
    private func crossProduct(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint) -> CGFloat {
        return (p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x)
    }
    
    // 輪郭オーバーレイ付きのプレビュー画像を作成
    func createContourPreview(image: UIImage, contour: [CGPoint]) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        // 元画像を描画
        image.draw(at: .zero)
        
        // 輪郭を描画
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
