import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @State private var showingPhotoReview = false
    @State private var activeSheet: ActiveSheet?
    
    enum ActiveSheet: Identifiable {
        case photoReview
        case weightInput
        
        var id: Int {
            switch self {
            case .photoReview: return 1
            case .weightInput: return 2
            }
        }
    }
    
    var body: some View {
        ZStack {
            if viewModel.isAuthorized {
                CameraPreviewView(cameraViewModel: viewModel)
                    .ignoresSafeArea(.container, edges: .top)
                
                // Overlay the saved guideline if available
                if let guideline = viewModel.savedGuideline,
                   viewModel.userSettings?.settings.showBodyGuidelines == true {
                    GeometryReader { geometry in
                        GuidelineOverlayView(
                            guideline: guideline,
                            viewSize: geometry.size,
                            currentCameraPosition: viewModel.currentCameraPosition
                        )
                    }
                    .ignoresSafeArea(.container, edges: .top)
                }
                
                VStack {
                    HStack {
                        Spacer()
                        
                        // Camera switch button
                        Button(action: {
                            viewModel.switchCamera()
                        }) {
                            Image(systemName: "camera.rotate")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 20)
                    }
                    .padding(.top, 60)
                    
                    if viewModel.userSettings?.settings.showBodyGuidelines == true {
                        BodyGuidelineView(isBodyDetected: viewModel.bodyDetected)
                    }
                    
                    Spacer()
                    
                    // Capture button above tab bar
                    CaptureButton {
                        viewModel.capturePhoto()
                    }
                    .padding(.bottom, 20)
                }
                .ignoresSafeArea(.container, edges: .top)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("Camera Access Required")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Please enable camera access in Settings to take photos")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    Button("Open Settings") {
                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsURL)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .onAppear {
            if viewModel.isAuthorized {
                viewModel.restartSession()
            } else {
                viewModel.checkAuthorization()
            }
            PhotoStorageService.shared.initialize()
        }
        .onDisappear {
            viewModel.stopSession()
        }
        .alert("Error", isPresented: $viewModel.showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
        .onChange(of: viewModel.capturedImage) { _, newValue in
            if newValue != nil {
                activeSheet = .photoReview
            }
        }
        .onChange(of: viewModel.showingWeightInput) { _, newValue in
            if newValue {
                activeSheet = .weightInput
            }
        }
        .alert("Only One Photo Per Day", isPresented: $viewModel.showingReplaceAlert) {
            Button("Replace", role: .destructive) {
                if let image = viewModel.capturedImage {
                    if viewModel.userSettings?.settings.isPremium == true {
                        viewModel.showingWeightInput = true
                    } else {
                        viewModel.savePhoto(image)
                        viewModel.capturedImage = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.capturedImage = nil
            }
        } message: {
            Text("You can only save one photo per day. Do you want to replace today's photo?")
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .photoReview:
                if let image = viewModel.capturedImage {
                    PhotoReviewView(
                        image: image,
                        onSave: { image in
                            viewModel.checkAndSavePhoto(image)
                            activeSheet = nil
                        },
                        onCancel: {
                            viewModel.capturedImage = nil
                            activeSheet = nil
                        }
                    )
                }
            case .weightInput:
                WeightInputSheet(
                    weight: $viewModel.tempWeight,
                    bodyFat: $viewModel.tempBodyFat,
                    onSave: {
                        if let image = viewModel.capturedImage {
                            viewModel.savePhoto(image)
                            viewModel.capturedImage = nil
                        }
                        viewModel.showingWeightInput = false
                        activeSheet = nil
                    },
                    onCancel: {
                        viewModel.capturedImage = nil
                        viewModel.tempWeight = nil
                        viewModel.tempBodyFat = nil
                        viewModel.showingWeightInput = false
                        activeSheet = nil
                    }
                )
            }
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let cameraViewModel: CameraViewModel
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        let previewLayer = cameraViewModel.cameraPreviewLayer
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        
        if let connection = previewLayer.connection {
            connection.videoRotationAngle = 90 // .portrait is 90 degrees
            // Only set video mirroring if automatic adjustment is disabled
            if connection.isVideoMirroringSupported && !connection.automaticallyAdjustsVideoMirroring {
                connection.isVideoMirrored = true
            }
        }
        
        view.layer.addSublayer(previewLayer)
        
        // Ensure the layer is properly sized when the view appears
        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Check if we need to recreate the preview layer
        let existingPreviewLayer = uiView.layer.sublayers?.compactMap({ $0 as? AVCaptureVideoPreviewLayer }).first
        
        if existingPreviewLayer == nil || existingPreviewLayer?.session == nil {
            // Remove any existing layers and recreate
            uiView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
            
            let previewLayer = cameraViewModel.cameraPreviewLayer
            previewLayer.frame = uiView.bounds
            previewLayer.videoGravity = .resizeAspectFill
            
            if let connection = previewLayer.connection {
                connection.videoRotationAngle = 90 // .portrait is 90 degrees
                if connection.isVideoMirroringSupported && !connection.automaticallyAdjustsVideoMirroring {
                    connection.isVideoMirrored = true
                }
            }
            
            uiView.layer.addSublayer(previewLayer)
        } else if let previewLayer = existingPreviewLayer {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer.frame = uiView.bounds
            CATransaction.commit()
            
            if let connection = previewLayer.connection {
                connection.videoRotationAngle = 90 // .portrait is 90 degrees
                if connection.isVideoMirroringSupported && !connection.automaticallyAdjustsVideoMirroring {
                    connection.isVideoMirrored = true
                }
            }
        }
    }
    
    func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        // Don't clean up the preview layer here as it will be reused
    }
}

struct CaptureButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.bodyLapseYellow)
                    .frame(width: 70, height: 70)
                
                Circle()
                    .stroke(Color.bodyLapseYellow, lineWidth: 3)
                    .frame(width: 80, height: 80)
            }
        }
    }
}

struct BodyGuidelineView: View {
    let isBodyDetected: Bool
    
    var body: some View {
        VStack {
            HStack(spacing: 5) {
                Image(systemName: isBodyDetected ? "figure.stand" : "figure.stand")
                    .foregroundColor(isBodyDetected ? .green : .orange)
                
                Text(isBodyDetected ? "Body detected" : "Align your body")
                    .font(.caption)
                    .foregroundColor(isBodyDetected ? .green : .orange)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.7))
            .cornerRadius(20)
        }
    }
}

struct GuidelineOverlayView: View {
    let guideline: BodyGuideline
    let viewSize: CGSize
    let currentCameraPosition: AVCaptureDevice.Position
    
    // Calculate scaled points with aspect fill logic (same as camera preview)
    private var aspectFillScaledContour: [CGPoint] {
        let originalSize = guideline.imageSize
        
        // Calculate scale factors for aspect fill
        let scaleX = viewSize.width / originalSize.width
        let scaleY = viewSize.height / originalSize.height
        // Use the larger scale to ensure the view is filled
        let scale = max(scaleX, scaleY)
        
        // Calculate the size after scaling
        let scaledWidth = originalSize.width * scale
        let scaledHeight = originalSize.height * scale
        
        // Calculate offset to center the scaled content
        let offsetX = (viewSize.width - scaledWidth) / 2
        let offsetY = (viewSize.height - scaledHeight) / 2
        
        // Get the guideline points
        var points = guideline.points
        
        // Check if we need to mirror the guideline
        // Mirror if:
        // - Guideline was captured with front camera AND we're now using back camera
        // - Guideline was captured with back camera AND we're now using front camera
        let shouldMirror = (guideline.isFrontCamera && currentCameraPosition == .back) ||
                          (!guideline.isFrontCamera && currentCameraPosition == .front)
        
        if shouldMirror {
            // Mirror the X coordinates
            points = points.map { point in
                CGPoint(x: originalSize.width - point.x, y: point.y)
            }
        }
        
        // Apply scale and offset to contour points
        return points.map { point in
            CGPoint(
                x: point.x * scale + offsetX,
                y: point.y * scale + offsetY
            )
        }
    }
    
    var body: some View {
        ZStack {
            let scaledContour = aspectFillScaledContour
            
            if !scaledContour.isEmpty && scaledContour.count > 2 {
                // Semi-transparent background fill
                Path { path in
                    path.move(to: scaledContour[0])
                    for i in 1..<scaledContour.count {
                        path.addLine(to: scaledContour[i])
                    }
                    path.closeSubpath()
                }
                .fill(Color.white.opacity(0.1))
                
                // Draw the contour outline
                Path { path in
                    path.move(to: scaledContour[0])
                    for i in 1..<scaledContour.count {
                        path.addLine(to: scaledContour[i])
                    }
                    path.closeSubpath()
                }
                .stroke(Color.green.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            }
        }
    }
}

