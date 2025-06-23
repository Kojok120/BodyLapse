import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @State private var showingPhotoReview = false
    
    var body: some View {
        ZStack {
            if viewModel.isAuthorized {
                CameraPreviewView(cameraViewModel: viewModel)
                    .ignoresSafeArea()
                
                VStack {
                    HStack {
                        if viewModel.userSettings.settings.showBodyGuidelines {
                            BodyGuidelineView(isBodyDetected: viewModel.bodyDetected)
                        }
                    }
                    .padding(.top, 50)
                    
                    Spacer()
                    
                    CaptureButton {
                        viewModel.capturePhoto()
                    }
                    .padding(.bottom, 30)
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
        .sheet(item: $viewModel.capturedImage) { _ in
            PhotoReviewView(
                image: viewModel.capturedImage!,
                onSave: { image in
                    viewModel.savePhoto(image)
                    viewModel.capturedImage = nil
                },
                onCancel: {
                    viewModel.capturedImage = nil
                }
            )
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let cameraViewModel: CameraViewModel
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = cameraViewModel.cameraPreviewLayer
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
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

extension UIImage: Identifiable {
    public var id: String { UUID().uuidString }
}