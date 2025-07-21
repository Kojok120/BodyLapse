import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Constants
private enum Constants {
    static let mosaicLineWidth: CGFloat = 40
    static let mosaicPixelSize = 50
    static let mosaicBrushRadius = 50
    static let maxImageSize: CGFloat = 2048
    static let minDrawDistance: CGFloat = 3
    static let pixelationStepSize = 5
    static let jpegQuality: CGFloat = 0.8
    static let progressLogInterval = 5
}

struct FaceBlurPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    
    let originalImage: UIImage
    @State private var processedImage: UIImage
    @State private var shareViewController: UIViewController?
    @State private var isEditingMode = false
    @State private var currentDrawPath: [CGPoint] = []
    @State private var allDrawPaths: [[CGPoint]] = []
    @State private var canvasSize: CGSize = .zero
    @State private var imageFrame: CGRect = .zero
    
    private let context = CIContext(options: [.useSoftwareRenderer: true])
    
    let onShare: (UIImage) -> Void
    
    init(originalImage: UIImage, processedImage: UIImage, onShare: @escaping (UIImage) -> Void) {
        self.originalImage = originalImage
        self._processedImage = State(initialValue: processedImage)
        self.onShare = onShare
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ツールバー
                HStack {
                    Button("戻る") {
                        dismiss()
                    }
                    
                    Spacer()
                    
                    Text(isEditingMode ? "モザイク編集" : "顔ぼかし確認")
                        .font(.headline)
                    
                    Spacer()
                    
                    if isEditingMode {
                        HStack(spacing: 12) {
                            // アンドゥボタン
                            Button(action: undoLastPath) {
                                Image(systemName: "arrow.uturn.backward")
                                    .foregroundColor(allDrawPaths.isEmpty ? .gray : .blue)
                            }
                            .disabled(allDrawPaths.isEmpty)
                            
                            // リセットボタン
                            Button(action: resetToOriginal) {
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundColor(.blue)
                            }
                            
                            // 完了ボタン
                            Button("完了") {
                                isEditingMode = false
                            }
                            .foregroundColor(.blue)
                        }
                    } else {
                        HStack(spacing: 12) {
                            // モザイク編集ボタン
                            Button(action: {
                                isEditingMode = true
                            }) {
                                Image(systemName: "scribble")
                                    .foregroundColor(.blue)
                            }
                            
                            // 共有ボタン
                            Button("共有") {
                                presentShareController()
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                // 画像プレビュー領域
                GeometryReader { geometry in
                    ZStack {
                        Color.black.ignoresSafeArea()
                        
                        Image(uiImage: processedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .background(
                                GeometryReader { imageGeometry in
                                    Color.clear
                                        .onAppear {
                                            updateImageFrame(imageGeometry: imageGeometry, containerSize: geometry.size)
                                        }
                                        .onChange(of: imageGeometry.size) { _, newSize in
                                            canvasSize = newSize
                                        }
                                }
                            )
                        
                        // モザイク描画オーバーレイ
                        if isEditingMode && canvasSize != .zero {
                            Canvas { context, size in
                                // 現在の描画パスを表示
                                if !currentDrawPath.isEmpty {
                                    drawMosaicPath(context: context, path: currentDrawPath, color: .red.opacity(0.6))
                                }
                                
                                // 完了済みパスを表示
                                for path in allDrawPaths {
                                    drawMosaicPath(context: context, path: path, color: .red.opacity(0.4))
                                }
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        handleDrawGesture(at: value.location)
                                    }
                                    .onEnded { _ in
                                        finishDrawing()
                                    }
                            )
                            .frame(width: canvasSize.width, height: canvasSize.height)
                        }
                        
                        // 編集モード時のガイダンス
                        if isEditingMode {
                            VStack {
                                Spacer()
                                HStack {
                                    Text("モザイクをかけたい場所をドラッグしてください")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(.black.opacity(0.7))
                                        .cornerRadius(8)
                                    Spacer()
                                }
                                .padding()
                            }
                        }
                    }
                    .onAppear {
                        canvasSize = geometry.size
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Helper Functions
    
    private func updateImageFrame(imageGeometry: GeometryProxy, containerSize: CGSize) {
        let imageSize = processedImage.size
        let aspectRatio = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height
        
        let displaySize: CGSize
        if aspectRatio > containerAspect {
            displaySize = CGSize(
                width: containerSize.width,
                height: containerSize.width / aspectRatio
            )
        } else {
            displaySize = CGSize(
                width: containerSize.height * aspectRatio,
                height: containerSize.height
            )
        }
        
        imageFrame = CGRect(
            x: (containerSize.width - displaySize.width) / 2,
            y: (containerSize.height - displaySize.height) / 2,
            width: displaySize.width,
            height: displaySize.height
        )
        canvasSize = containerSize
    }
    
    private func drawMosaicPath(context: GraphicsContext, path: [CGPoint], color: Color) {
        guard path.count > 1 else { return }
        
        var cgPath = Path()
        cgPath.move(to: path[0])
        for point in path.dropFirst() {
            cgPath.addLine(to: point)
        }
        
        context.stroke(cgPath, with: .color(color), style: StrokeStyle(
            lineWidth: Constants.mosaicLineWidth, 
            lineCap: .round, 
            lineJoin: .round
        ))
    }
    
    private func handleDrawGesture(at location: CGPoint) {
        guard imageFrame.contains(location) else { return }
        
        if currentDrawPath.isEmpty || 
           distance(from: currentDrawPath.last!, to: location) > Constants.minDrawDistance {
            currentDrawPath.append(location)
        }
    }
    
    private func finishDrawing() {
        guard !currentDrawPath.isEmpty else { return }
        
        allDrawPaths.append(currentDrawPath)
        applyMosaicToPath(currentDrawPath)
        currentDrawPath.removeAll()
    }
    
    private func distance(from: CGPoint, to: CGPoint) -> CGFloat {
        let dx = from.x - to.x
        let dy = from.y - to.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private func applyMosaicToPath(_ path: [CGPoint]) {
        Task {
            guard let mosaicImage = await MosaicProcessor.applyMosaicAlongPath(
                to: processedImage, 
                path: path, 
                imageFrame: imageFrame
            ) else { 
                print("❌ Failed to apply mosaic")
                return 
            }
            
            await MainActor.run {
                processedImage = mosaicImage
            }
        }
    }
    
    private func undoLastPath() {
        guard !allDrawPaths.isEmpty else { return }
        
        allDrawPaths.removeLast()
        
        // 元画像から再構築
        Task {
            let blurMethod = UserSettingsManager.shared.settings.faceBlurMethod.toServiceMethod
            let baseImage = await FaceBlurService.shared.processImageAsync(originalImage, blurMethod: blurMethod)
            
            var currentImage = baseImage
            
            // 残っているパスを順番に適用
            for path in allDrawPaths {
                if let mosaicImage = await MosaicProcessor.applyMosaicAlongPath(
                    to: currentImage, 
                    path: path, 
                    imageFrame: imageFrame
                ) {
                    currentImage = mosaicImage
                }
            }
            
            await MainActor.run {
                processedImage = currentImage
            }
        }
    }
    
    private func resetToOriginal() {
        Task {
            let blurMethod = UserSettingsManager.shared.settings.faceBlurMethod.toServiceMethod
            let reprocessedImage = await FaceBlurService.shared.processImageAsync(originalImage, blurMethod: blurMethod)
            
            await MainActor.run {
                processedImage = reprocessedImage
                allDrawPaths.removeAll()
                currentDrawPath.removeAll()
            }
        }
    }
    
    private func presentShareController() {
        guard let optimizedImage = optimizeImageForSharing(processedImage) else {
            print("❌ Failed to optimize image")
            return
        }
        
        let activityController = createActivityController(with: optimizedImage)
        shareViewController = activityController
        showActivityController(activityController)
    }
    
    private func createActivityController(with image: UIImage) -> UIActivityViewController {
        let activityController = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        activityController.modalPresentationStyle = .pageSheet
        activityController.completionWithItemsHandler = { _, completed, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Share error: \(error)")
                }
            }
        }
        
        configurePopoverIfNeeded(for: activityController)
        return activityController
    }
    
    private func configurePopoverIfNeeded(for activityController: UIActivityViewController) {
        if let popover = activityController.popoverPresentationController,
           let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            popover.sourceView = rootVC.view
            popover.sourceRect = CGRect(
                x: rootVC.view.bounds.midX,
                y: rootVC.view.bounds.maxY - 100,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = [.down, .up]
        }
    }
    
    private func showActivityController(_ activityController: UIActivityViewController) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else {
            return
        }
        
        var presentingVC = rootVC
        while let presented = presentingVC.presentedViewController {
            presentingVC = presented
        }
        
        presentingVC.present(activityController, animated: true)
    }
    
    private func optimizeImageForSharing(_ image: UIImage) -> UIImage? {
        return ImageOptimizer.optimizeForSharing(
            image: image,
            maxSize: Constants.maxImageSize,
            quality: Constants.jpegQuality
        )
    }
}

// MARK: - Supporting Structures

struct MosaicProcessor {
    static func applyMosaicAlongPath(
        to image: UIImage, 
        path: [CGPoint], 
        imageFrame: CGRect
    ) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let cgImage = image.cgImage else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let imageSize = image.size
                let scaledPath = PathScaler.scalePathToImageCoordinates(
                    path: path,
                    imageFrame: imageFrame,
                    imageSize: imageSize
                )
                
                guard let result = PixelProcessor.applyPixelation(
                    to: cgImage,
                    path: scaledPath,
                    imageSize: imageSize
                ) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let finalImage = UIImage(cgImage: result, scale: image.scale, orientation: image.imageOrientation)
                continuation.resume(returning: finalImage)
            }
        }
    }
}

struct PathScaler {
    static func scalePathToImageCoordinates(
        path: [CGPoint],
        imageFrame: CGRect,
        imageSize: CGSize
    ) -> [CGPoint] {
        guard imageFrame.width > 0 && imageFrame.height > 0 else {
            return []
        }
        
        let scaleX = imageSize.width / imageFrame.width
        let scaleY = imageSize.height / imageFrame.height
        
        return path.map { point in
            CGPoint(
                x: max(0, min(imageSize.width, (point.x - imageFrame.minX) * scaleX)),
                y: max(0, min(imageSize.height, (point.y - imageFrame.minY) * scaleY))
            )
        }
    }
}

struct PixelProcessor {
    static func applyPixelation(
        to cgImage: CGImage,
        path: [CGPoint],
        imageSize: CGSize
    ) -> CGImage? {
        let width = Int(imageSize.width)
        let height = Int(imageSize.height)
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(origin: .zero, size: imageSize))
        
        guard let data = context.data else {
            return nil
        }
        
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        var processedBlocks = Set<String>()
        
        for point in path {
            processPixelBlock(
                pixels: pixels,
                centerX: Int(point.x),
                centerY: Int(point.y),
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                processedBlocks: &processedBlocks
            )
        }
        
        return context.makeImage()
    }
    
    private static func processPixelBlock(
        pixels: UnsafeMutablePointer<UInt8>,
        centerX: Int,
        centerY: Int,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        processedBlocks: inout Set<String>
    ) {
        guard centerX >= 0, centerX < width, centerY >= 0, centerY < height else {
            return
        }
        
        for dy in stride(from: -Constants.mosaicBrushRadius, through: Constants.mosaicBrushRadius, by: Constants.pixelationStepSize) {
            for dx in stride(from: -Constants.mosaicBrushRadius, through: Constants.mosaicBrushRadius, by: Constants.pixelationStepSize) {
                let pixelX = centerX + dy
                let pixelY = centerY + dx
                
                let distanceSquared = dx * dx + dy * dy
                if distanceSquared <= Constants.mosaicBrushRadius * Constants.mosaicBrushRadius,
                   pixelX >= 0, pixelX < width, pixelY >= 0, pixelY < height {
                    
                    applyMosaicToBlock(
                        pixels: pixels,
                        blockX: (pixelX / Constants.mosaicPixelSize) * Constants.mosaicPixelSize,
                        blockY: (pixelY / Constants.mosaicPixelSize) * Constants.mosaicPixelSize,
                        width: width,
                        height: height,
                        bytesPerRow: bytesPerRow,
                        processedBlocks: &processedBlocks
                    )
                }
            }
        }
    }
    
    private static func applyMosaicToBlock(
        pixels: UnsafeMutablePointer<UInt8>,
        blockX: Int,
        blockY: Int,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        processedBlocks: inout Set<String>
    ) {
        let blockKey = "\(blockX)-\(blockY)"
        guard !processedBlocks.contains(blockKey) else { return }
        processedBlocks.insert(blockKey)
        
        let blockEndX = min(blockX + Constants.mosaicPixelSize, width)
        let blockEndY = min(blockY + Constants.mosaicPixelSize, height)
        
        // Calculate average color
        var totalR = 0, totalG = 0, totalB = 0, totalA = 0, count = 0
        
        for by in blockY..<blockEndY {
            for bx in blockX..<blockEndX {
                let offset = by * bytesPerRow + bx * 4
                if offset >= 0 && offset + 3 < bytesPerRow * height {
                    totalR += Int(pixels[offset])
                    totalG += Int(pixels[offset + 1])
                    totalB += Int(pixels[offset + 2])
                    totalA += Int(pixels[offset + 3])
                    count += 1
                }
            }
        }
        
        guard count > 0 else { return }
        
        let avgR = UInt8(totalR / count)
        let avgG = UInt8(totalG / count)
        let avgB = UInt8(totalB / count)
        let avgA = UInt8(totalA / count)
        
        // Apply average color to entire block
        for by in blockY..<blockEndY {
            for bx in blockX..<blockEndX {
                let offset = by * bytesPerRow + bx * 4
                if offset >= 0 && offset + 3 < bytesPerRow * height {
                    pixels[offset] = avgR
                    pixels[offset + 1] = avgG
                    pixels[offset + 2] = avgB
                    pixels[offset + 3] = avgA
                }
            }
        }
    }
}

struct ImageOptimizer {
    static func optimizeForSharing(
        image: UIImage,
        maxSize: CGFloat,
        quality: CGFloat
    ) -> UIImage? {
        let newSize = calculateOptimalSize(for: image.size, maxSize: maxSize)
        
        guard let cgImage = image.cgImage,
              let context = createContext(size: newSize) else {
            return nil
        }
        
        // Draw white background and image
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: newSize))
        context.draw(cgImage, in: CGRect(origin: .zero, size: newSize))
        
        guard let newCGImage = context.makeImage() else {
            return nil
        }
        
        let cleanImage = UIImage(cgImage: newCGImage)
        
        guard let jpegData = cleanImage.jpegData(compressionQuality: quality),
              let finalImage = UIImage(data: jpegData) else {
            return nil
        }
        
        return finalImage
    }
    
    private static func calculateOptimalSize(for originalSize: CGSize, maxSize: CGFloat) -> CGSize {
        guard max(originalSize.width, originalSize.height) > maxSize else {
            return originalSize
        }
        
        let aspectRatio = originalSize.width / originalSize.height
        if originalSize.width > originalSize.height {
            return CGSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            return CGSize(width: maxSize * aspectRatio, height: maxSize)
        }
    }
    
    private static func createContext(size: CGSize) -> CGContext? {
        return CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }
}

#Preview {
    FaceBlurPreviewView(
        originalImage: UIImage(systemName: "photo") ?? UIImage(),
        processedImage: UIImage(systemName: "photo") ?? UIImage()
    ) { _ in }
}