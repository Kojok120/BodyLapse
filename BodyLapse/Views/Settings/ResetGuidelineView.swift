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
    @State private var timerDuration: Int = 0 // 0 = off, 3, 5, 10 seconds
    @State private var countdownValue: Int = 0
    @State private var isCountingDown = false
    
    let categoryId: String?
    let categoryName: String?
    
    init(categoryId: String? = nil, categoryName: String? = nil) {
        self.categoryId = categoryId
        self.categoryName = categoryName
    }
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .edgesIgnoringSafeArea(.all)
            
            if shouldShowCamera && !showingContourConfirmation {
                SimpleCameraView { image in
                    handlePhotoCapture(image)
                } onReady: { controller in
                    cameraController = controller
                    controller.timerDuration = timerDuration
                    controller.onCountdownUpdate = { value in
                        countdownValue = value
                        isCountingDown = value > 0
                    }
                    controller.onCountdownComplete = {
                        isCountingDown = false
                    }
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
                        
                        // Timer button
                        Menu {
                            Button(action: { 
                                timerDuration = 0
                                cameraController?.timerDuration = 0
                            }) {
                                Label("timer.off".localized, systemImage: timerDuration == 0 ? "checkmark" : "")
                            }
                            Button(action: { 
                                timerDuration = 3
                                cameraController?.timerDuration = 3
                            }) {
                                Label("timer.3s".localized, systemImage: timerDuration == 3 ? "checkmark" : "")
                            }
                            Button(action: { 
                                timerDuration = 5
                                cameraController?.timerDuration = 5
                            }) {
                                Label("timer.5s".localized, systemImage: timerDuration == 5 ? "checkmark" : "")
                            }
                            Button(action: { 
                                timerDuration = 10
                                cameraController?.timerDuration = 10
                            }) {
                                Label("timer.10s".localized, systemImage: timerDuration == 10 ? "checkmark" : "")
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                    .font(.system(size: 20))
                                if timerDuration > 0 {
                                    Text("\(timerDuration)s")
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .disabled(cameraController == nil)
                        .opacity(cameraController == nil ? 0.5 : 1.0)
                        
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
                    
                    // Countdown display
                    if isCountingDown {
                        Text("\(countdownValue)")
                            .font(.system(size: 120, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                            .transition(.scale.combined(with: .opacity))
                            .animation(.easeInOut(duration: 0.3), value: countdownValue)
                    }
                    
                    Spacer()
                
                    VStack(spacing: 20) {
                        Text("settings.reset_guideline".localized)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                        
                        if let name = categoryName {
                            Text(name)
                                .font(.headline)
                                .foregroundColor(.bodyLapseTurquoise)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(20)
                        }
                        
                        Text("reset_guideline.instruction".localized)
                            .font(.body)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .shadow(radius: 2)
                        
                        if isCountingDown {
                            Button(action: {
                                cameraController?.cancelCountdown()
                                isCountingDown = false
                                countdownValue = 0
                            }) {
                                Text("common.cancel".localized)
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.red.opacity(0.8))
                                    .cornerRadius(20)
                            }
                        } else {
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
                        }
                    }
                    .padding()
                    .padding(.bottom, 40)
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
        .onChange(of: showingSuccessAlert) { _, newValue in
            if newValue {
                // Auto-dismiss after successful save
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            }
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
                if let categoryId = self.categoryId {
                    GuidelineStorageService.shared.saveGuideline(guideline, for: categoryId)
                } else {
                    GuidelineStorageService.shared.saveGuideline(guideline)
                }
                
                // Notify that guideline has been updated
                DispatchQueue.main.async {
                    let userInfo: [String: Any] = ["categoryId": self.categoryId ?? PhotoCategory.defaultCategory.id]
                    NotificationCenter.default.post(name: Notification.Name("GuidelineUpdated"), object: nil, userInfo: userInfo)
                    print("ResetGuidelineView: Posted GuidelineUpdated notification for category: \(self.categoryId ?? PhotoCategory.defaultCategory.id)")
                }
            }
            
            DispatchQueue.main.async { [self] in
                self.isProcessing = false
                self.showingSuccessAlert = true
            }
        }
    }
}