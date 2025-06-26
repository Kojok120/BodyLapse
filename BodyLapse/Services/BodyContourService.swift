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
        
        if #available(iOS 17.0, *) {
            // Use the new foreground instance mask for iOS 17+
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
                
                // Create a handler for the original image
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                
                // Extract contour from the foreground mask
                self?.extractContourFromForegroundMask(observation: observation, handler: handler, imageSize: CGSize(width: cgImage.width, height: cgImage.height)) { result in
                    DispatchQueue.main.async {
                        completion(result)
                    }
                }
            }
            
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
        } else {
            // Fallback to saliency detection for older iOS versions
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
                
                // Extract contour from saliency heat map
                self?.extractContourFromSaliency(observation: observation, imageSize: CGSize(width: cgImage.width, height: cgImage.height)) { result in
                    DispatchQueue.main.async {
                        completion(result)
                    }
                }
            }
            
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
    }
    
    @available(iOS 17.0, *)
    private func extractContourFromForegroundMask(observation: VNObservation, handler: VNImageRequestHandler, imageSize: CGSize, completion: @escaping (Result<[CGPoint], Error>) -> Void) {
        guard let instanceMask = observation as? VNInstanceMaskObservation else {
            completion(.failure(ContourError.imageProcessingFailed))
            return
        }
        
        // Get all instances
        let instances = instanceMask.allInstances
        guard !instances.isEmpty else {
            completion(.failure(ContourError.noPersonDetected))
            return
        }
        
        // Use the first instance (usually the most prominent)
        let firstInstance = instances.first!
        
        print("Detected \(instances.count) instances, using instance: \(firstInstance)")
        
        // Generate a mask for the specific instance
        do {
            // Generate scaled mask for the selected instance
            let maskedPixelBuffer = try instanceMask.generateScaledMaskForImage(
                forInstances: IndexSet(integer: firstInstance),
                from: handler
            )
            
            // Debug: Print mask information
            let maskWidth = CVPixelBufferGetWidth(maskedPixelBuffer)
            let maskHeight = CVPixelBufferGetHeight(maskedPixelBuffer)
            print("Mask size: \(maskWidth)x\(maskHeight)")
            
            // Debug: Save mask as image for inspection
            debugSaveMask(pixelBuffer: maskedPixelBuffer)
            
            // Extract contour from the masked pixel buffer
            extractContourFromMask(pixelBuffer: maskedPixelBuffer, imageSize: imageSize, completion: completion)
        } catch {
            print("Failed to generate scaled mask: \(error)")
            // Try generating masked image instead
            do {
                let maskedImage = try instanceMask.generateMaskedImage(
                    ofInstances: IndexSet(integer: firstInstance),
                    from: handler,
                    croppedToInstancesExtent: false
                )
                
                print("Using masked image fallback")
                
                // Extract contour from the masked image
                extractContourFromMask(pixelBuffer: maskedImage, imageSize: imageSize, completion: completion)
            } catch {
                print("Failed to generate masked image: \(error)")
                completion(.failure(ContourError.imageProcessingFailed))
            }
        }
    }
    
    private func debugSaveMask(pixelBuffer: CVPixelBuffer) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let uiImage = UIImage(cgImage: cgImage)
            
            // Save to temporary directory for debugging
            if let data = uiImage.pngData() {
                let tempDir = FileManager.default.temporaryDirectory
                let maskURL = tempDir.appendingPathComponent("debug_mask_\(Date().timeIntervalSince1970).png")
                try? data.write(to: maskURL)
                print("Debug mask saved to: \(maskURL.path)")
            }
        }
    }
    
    private func extractContourFromMask(pixelBuffer: CVPixelBuffer, imageSize: CGSize, completion: @escaping (Result<[CGPoint], Error>) -> Void) {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // Check pixel format
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        print("Pixel format: \(pixelFormat)")
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            completion(.failure(ContourError.imageProcessingFailed))
            return
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        // Check if it's float format
        let isFloatFormat = pixelFormat == kCVPixelFormatType_DepthFloat32
        
        if isFloatFormat {
            // Handle float pixel format
            extractContourFromFloatMask(baseAddress: baseAddress, width: width, height: height, bytesPerRow: bytesPerRow, imageSize: imageSize, completion: completion)
        } else {
            // Handle byte pixel format
            let pixelData = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        // Debug: Check pixel value range
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
        
        // Determine threshold based on the pixel value range
        let threshold: UInt8 = maxPixelValue > 1 ? maxPixelValue / 2 : 0
        print("Using threshold: \(threshold)")
        
        // Step 1: Find all edge pixels
        var edgePixels: [(x: Int, y: Int)] = []
        
        // Scan the image to find edge pixels
        for y in 1..<height-1 {
            for x in 1..<width-1 {
                let pixelIndex = y * bytesPerRow + x
                let currentPixel = pixelData[pixelIndex]
                
                if currentPixel > threshold {
                    // Check if this is an edge pixel (has at least one background neighbor)
                    var hasBackgroundNeighbor = false
                    
                    // Check 8-connected neighbors
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
                            // Image boundary counts as background
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
        
        // Step 2: Use chain code to trace the outer contour
        guard !edgePixels.isEmpty else {
            completion(.failure(ContourError.noPersonDetected))
            return
        }
        
        // Create edge map for fast lookup
        var edgeMap = [[Bool]](repeating: [Bool](repeating: false, count: width), count: height)
        for edge in edgePixels {
            edgeMap[edge.y][edge.x] = true
        }
        
        // Find starting point (topmost, then leftmost)
        let startPoint = edgePixels.min { a, b in
            if a.y != b.y { return a.y < b.y }
            return a.x < b.x
        }!
        
        // Trace the contour using Moore neighborhood tracing
        var contourPoints: [CGPoint] = []
        var current = startPoint
        var visited = Set<String>()
        
        // Direction codes: 0=E, 1=SE, 2=S, 3=SW, 4=W, 5=NW, 6=N, 7=NE
        let directions = [(1,0), (1,1), (0,1), (-1,1), (-1,0), (-1,-1), (0,-1), (1,-1)]
        var dir = 0 // Start direction
        
        let maxSteps = edgePixels.count * 2
        var steps = 0
        
        repeat {
            // Add current point to contour
            let scaledX = CGFloat(current.x) * imageSize.width / CGFloat(width)
            let scaledY = CGFloat(current.y) * imageSize.height / CGFloat(height)
            contourPoints.append(CGPoint(x: scaledX, y: scaledY))
            
            let key = "\(current.x),\(current.y)"
            visited.insert(key)
            
            // Find next point
            var found = false
            let startDir = (dir + 5) % 8 // Start search from 90 degrees counter-clockwise
            
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
            
            // Stop conditions
            if !found || steps >= maxSteps {
                break
            }
            
            // Check if we've returned to start
            if current.x == startPoint.x && current.y == startPoint.y && steps > 8 {
                break
            }
            
        } while true
        
        print("Traced contour with \(contourPoints.count) points")
        
        // If contour tracing didn't work well, use all edge pixels
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
        
        // Step 3: Sort edge points by angle to create ordered contour
        // Find center point of all edge pixels
        let centerX = contourPoints.reduce(0) { $0 + $1.x } / CGFloat(contourPoints.count)
        let centerY = contourPoints.reduce(0) { $0 + $1.y } / CGFloat(contourPoints.count)
        
        // Sort points by angle from center
        let sortedContour = contourPoints.sorted { point1, point2 in
            let angle1 = atan2(point1.y - centerY, point1.x - centerX)
            let angle2 = atan2(point2.y - centerY, point2.x - centerX)
            return angle1 < angle2
        }
        
        // Sample points if too many
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
        
        // Step 4: Apply smoothing
        let smoothedContour = smoothContourAggressive(finalContour)
        completion(.success(smoothedContour))
        }
    }
    
    private func extractContourFromFloatMask(baseAddress: UnsafeRawPointer, width: Int, height: Int, bytesPerRow: Int, imageSize: CGSize, completion: @escaping (Result<[CGPoint], Error>) -> Void) {
        let pixelData = baseAddress.assumingMemoryBound(to: Float32.self)
        
        // Debug: Check pixel value range
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
        
        // Determine threshold based on the pixel value range
        let threshold: Float32 = maxPixelValue > 0 ? maxPixelValue * 0.5 : 0
        print("Using float threshold: \(threshold)")
        
        // Find edge pixels
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
        
        // Convert edge pixels to contour points
        var contourPoints: [CGPoint] = []
        for edge in edgePixels {
            let scaledX = CGFloat(edge.x) * imageSize.width / CGFloat(width)
            let scaledY = CGFloat(edge.y) * imageSize.height / CGFloat(height)
            contourPoints.append(CGPoint(x: scaledX, y: scaledY))
        }
        
        // Sort by angle from center for better ordering
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
        
        // Convert saliency map to binary mask
        // Create a threshold filter to convert grayscale saliency to binary
        guard let thresholdFilter = CIFilter(name: "CIColorMonochrome") else {
            completion(.failure(ContourError.imageProcessingFailed))
            return
        }
        
        thresholdFilter.setValue(ciImage, forKey: kCIInputImageKey)
        thresholdFilter.setValue(CIColor(red: 1, green: 1, blue: 1), forKey: "inputColor")
        thresholdFilter.setValue(0.3, forKey: "inputIntensity") // Adjust threshold as needed
        
        guard let outputImage = thresholdFilter.outputImage,
              let binaryImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            completion(.failure(ContourError.imageProcessingFailed))
            return
        }
        
        // Extract contour points from binary image
        var contourPoints = extractBoundaryPoints(from: binaryImage, originalSize: imageSize)
        
        // If we don't have enough points, try a different approach
        if contourPoints.count < 20 {
            contourPoints = extractContourUsingEdgeDetection(from: cgImage, originalSize: imageSize)
        }
        
        completion(.success(contourPoints))
    }
    
    private func extractBoundaryPoints(from cgImage: CGImage, originalSize: CGSize) -> [CGPoint] {
        let width = cgImage.width
        let height = cgImage.height
        
        // Get pixel data
        guard let data = cgImage.dataProvider?.data,
              let pixels = CFDataGetBytePtr(data) else {
            return []
        }
        
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        
        var boundaryPoints: [CGPoint] = []
        
        // Scan from multiple directions to find boundary
        let scanAngles = stride(from: 0, to: 360, by: 5)
        let centerX = CGFloat(width) / 2
        let centerY = CGFloat(height) / 2
        
        for angle in scanAngles {
            let radians = CGFloat(angle) * .pi / 180
            let maxRadius = min(centerX, centerY) * 1.5
            
            // Scan outward from center
            for radius in stride(from: 0, to: maxRadius, by: 2) {
                let x = Int(centerX + radius * cos(radians))
                let y = Int(centerY + radius * sin(radians))
                
                if x >= 0 && x < width && y >= 0 && y < height {
                    let pixelIndex = y * bytesPerRow + x * bytesPerPixel
                    let pixelValue = pixels[pixelIndex]
                    
                    // Check if this is a salient pixel (bright in the saliency map)
                    if pixelValue > 100 {
                        // Scale to original image size
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
        // Alternative approach using edge detection
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext()
        
        // Apply edge detection
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
        
        // Convert to binary image and find contour
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        print("Extracting contour from mask of size: \(width)x\(height)")
        
        // Edge detection approach - trace the outline
        
        // Find starting point from top
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
        
        // Trace outline using edge following algorithm
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
        
        // Trace the edge
        var edgePoints: [CGPoint] = []
        var lastDirection = 0
        
        repeat {
            let key = "\(Int(current.x)),\(Int(current.y))"
            if visited.contains(key) && edgePoints.count > 20 {
                break
            }
            visited.insert(key)
            
            // Check if this is an edge point (has at least one non-person neighbor)
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
            
            // Find next edge point
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
        
        // Sample edge points to reduce density
        let targetPoints = 72  // One point every 5 degrees
        let step = max(1, edgePoints.count / targetPoints)
        var sampledPoints: [CGPoint] = []
        
        for i in stride(from: 0, to: edgePoints.count, by: step) {
            let point = edgePoints[i]
            // Scale to original image size
            let scaledX = point.x * imageSize.width / CGFloat(width)
            let scaledY = point.y * imageSize.height / CGFloat(height)
            sampledPoints.append(CGPoint(x: scaledX, y: scaledY))
        }
        
        print("Sampled to \(sampledPoints.count) contour points")
        
        // Smooth the contour
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
        
        // Vision framework person segmentation uses confidence values
        // Higher values indicate higher confidence that the pixel belongs to a person
        let pixelValue = pixel[offset]
        
        // Use a lower threshold for better detection
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
        
        // First pass: basic smoothing
        var smoothed = smoothContour(points)
        
        // Second pass: apply Gaussian-like smoothing with larger window
        let windowSize = 5
        var finalSmoothed: [CGPoint] = []
        
        for i in 0..<smoothed.count {
            var sumX: CGFloat = 0
            var sumY: CGFloat = 0
            var totalWeight: CGFloat = 0
            
            for j in -windowSize...windowSize {
                let index = (i + j + smoothed.count) % smoothed.count
                // Gaussian-like weighting - closer points have more influence
                let weight = exp(-pow(CGFloat(j), 2) / (2 * pow(CGFloat(windowSize) / 2, 2)))
                sumX += smoothed[index].x * weight
                sumY += smoothed[index].y * weight
                totalWeight += weight
            }
            
            finalSmoothed.append(CGPoint(x: sumX / totalWeight, y: sumY / totalWeight))
        }
        
        // Third pass: remove outliers and re-smooth
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
                // Replace outlier with interpolated point
                filtered.append(centerPoint)
            }
        }
        
        // Final smoothing pass
        return smoothContour(filtered)
    }
    
    private func distance(from point1: CGPoint, to point2: CGPoint) -> CGFloat {
        return sqrt(pow(point1.x - point2.x, 2) + pow(point1.y - point2.y, 2))
    }
    
    // Convex hull using Graham scan algorithm
    private func convexHull(points: [CGPoint]) -> [CGPoint] {
        guard points.count >= 3 else { return points }
        
        // Find the point with the lowest y-coordinate (and leftmost if tie)
        let start = points.min { a, b in
            if a.y != b.y { return a.y < b.y }
            return a.x < b.x
        }!
        
        // Sort points by polar angle with respect to start point
        let sortedPoints = points.filter { $0 != start }.sorted { a, b in
            let angleA = atan2(a.y - start.y, a.x - start.x)
            let angleB = atan2(b.y - start.y, b.x - start.x)
            if angleA != angleB { return angleA < angleB }
            // If angles are equal, closer point comes first
            let distA = distance(from: start, to: a)
            let distB = distance(from: start, to: b)
            return distA < distB
        }
        
        // Build convex hull
        var hull = [start]
        
        for point in sortedPoints {
            // Remove points that make clockwise turn
            while hull.count > 1 && crossProduct(hull[hull.count-2], hull[hull.count-1], point) <= 0 {
                hull.removeLast()
            }
            hull.append(point)
        }
        
        return hull
    }
    
    // Cross product of vectors (p1->p2) and (p1->p3)
    private func crossProduct(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint) -> CGFloat {
        return (p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x)
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