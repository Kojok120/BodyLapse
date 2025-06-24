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
                    .ignoresSafeArea()
                
                VStack {
                    HStack {
                        if viewModel.userSettings?.settings.showBodyGuidelines == true {
                            BodyGuidelineView(isBodyDetected: viewModel.bodyDetected)
                        }
                    }
                    .padding(.top, 50)
                    
                    Spacer()
                }
                // Capture button above bottom safe area (e.g., TabBar)
                .safeAreaInset(edge: .bottom) {
                    CaptureButton {
                        viewModel.capturePhoto()
                    }
                    .padding(.bottom, 10)
                }
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
            viewModel.checkAuthorization()
            PhotoStorageService.shared.initialize()
        }
        .alert("Error", isPresented: $viewModel.showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
        .onChange(of: viewModel.capturedImage) { newValue in
            if newValue != nil {
                activeSheet = .photoReview
            }
        }
        .onChange(of: viewModel.showingWeightInput) { newValue in
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
            connection.videoOrientation = .portrait
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
        if let previewLayer = uiView.layer.sublayers?.compactMap({ $0 as? AVCaptureVideoPreviewLayer }).first {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer.frame = uiView.bounds
            CATransaction.commit()
            
            if let connection = previewLayer.connection {
                connection.videoOrientation = .portrait
                // Only set video mirroring if automatic adjustment is disabled
                if connection.isVideoMirroringSupported && !connection.automaticallyAdjustsVideoMirroring {
                    connection.isVideoMirrored = true
                }
            }
        }
    }
}

struct CaptureButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 70, height: 70)
                
                Circle()
                    .stroke(Color.white, lineWidth: 3)
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

