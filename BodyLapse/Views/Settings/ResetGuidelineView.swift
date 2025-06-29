import SwiftUI

struct ResetGuidelineView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cameraController: SimpleCameraViewController?
    @State private var isProcessing = false
    @State private var capturedImage: UIImage?
    @State private var detectedContour: [CGPoint]?
    @State private var showingContourConfirmation = false
    @State private var contourError: String?
    @State private var shouldShowCamera = true
    @State private var showingSuccessAlert = false
    
    var body: some View {
        ZStack {
            if shouldShowCamera && !showingContourConfirmation {
                SimpleCameraView { image in
                    handlePhotoCapture(image)
                } onReady: { controller in
                    cameraController = controller
                }
                .edgesIgnoringSafeArea(.all)
            } else if let image = capturedImage, let contour = detectedContour {
                ContourConfirmationView(
                    image: image,
                    contour: contour,
                    onConfirm: {
                        saveNewGuideline(image: image, contour: contour)
                    },
                    onRetry: {
                        resetForRetake()
                    }
                )
            }
            
            if shouldShowCamera && !showingContourConfirmation {
                VStack {
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .padding()
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .padding(.leading, 20)
                        .padding(.top, 60)
                        
                        Spacer()
                        
                        Button(action: {
                            guard let controller = cameraController else { return }
                            controller.switchCamera()
                        }) {
                            Image(systemName: "camera.rotate")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .padding()
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .disabled(cameraController == nil)
                        .opacity(cameraController == nil ? 0.5 : 1.0)
                        .padding(.trailing, 20)
                        .padding(.top, 60)
                    }
                    
                    Spacer()
                
                    VStack(spacing: 20) {
                        Text("settings.reset_guideline".localized)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                        
                        Text("reset_guideline.instruction".localized)
                            .font(.body)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .shadow(radius: 2)
                        
                        Button(action: {
                            guard let controller = cameraController, !isProcessing else { return }
                            controller.capturePhoto()
                        }) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                        .frame(width: 80, height: 80)
                                )
                        }
                        .disabled(isProcessing || cameraController == nil)
                        .opacity(isProcessing || cameraController == nil ? 0.5 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: cameraController == nil)
                        .padding(.bottom, 40)
                    }
                    .padding()
                }
            }
            
            if isProcessing {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .alert("common.done".localized, isPresented: $showingSuccessAlert) {
            Button("common.ok".localized) {
                dismiss()
            }
        } message: {
            Text("reset_guideline.success_message".localized)
        }
    }
    
    private func handlePhotoCapture(_ image: UIImage) {
        isProcessing = true
        capturedImage = image
        
        BodyContourService.shared.detectBodyContour(from: image) { result in
            DispatchQueue.main.async { [self] in
                switch result {
                case .success(let contour):
                    print("ResetGuidelineView: Detected \(contour.count) contour points")
                    self.detectedContour = contour
                    self.isProcessing = false
                    self.showingContourConfirmation = true
                    
                case .failure(let error):
                    print("Failed to detect body contour: \(error)")
                    self.contourError = error.localizedDescription
                    self.isProcessing = false
                    self.detectedContour = []
                    self.showingContourConfirmation = true
                }
            }
        }
    }
    
    private func resetForRetake() {
        showingContourConfirmation = false
        capturedImage = nil
        detectedContour = nil
        contourError = nil
        isProcessing = false
        cameraController = nil
        
        shouldShowCamera = false
        
        DispatchQueue.main.async {
            self.shouldShowCamera = true
        }
    }
    
    private func saveNewGuideline(image: UIImage, contour: [CGPoint]) {
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            if !contour.isEmpty {
                let isFrontCamera = self.cameraController?.currentPosition == .front
                var finalContour = contour
                
                if isFrontCamera {
                    finalContour = contour.map { point in
                        CGPoint(x: image.size.width - point.x, y: point.y)
                    }
                }
                
                let guideline = BodyGuideline(points: finalContour, imageSize: image.size, isFrontCamera: isFrontCamera)
                GuidelineStorageService.shared.saveGuideline(guideline)
                
                // Notify that guideline has been updated
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name("GuidelineUpdated"), object: nil)
                }
            }
            
            DispatchQueue.main.async { [self] in
                self.isProcessing = false
                self.showingSuccessAlert = true
            }
        }
    }
}