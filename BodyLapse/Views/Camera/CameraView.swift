import SwiftUI
import AVFoundation

struct CameraView: View {
    @Binding var shouldLaunchCamera: Bool
    @StateObject private var viewModel = CameraViewModel()
    @ObservedObject private var userSettings = UserSettingsManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManagerService.shared
    @State private var showingPhotoReview = false
    @State private var activeSheet: ActiveSheet?
    @State private var showingAddCategory = false
    @State private var newCategoryToSetup: PhotoCategory?
    
    init(shouldLaunchCamera: Binding<Bool> = .constant(false)) {
        self._shouldLaunchCamera = shouldLaunchCamera
    }
    
    enum ActiveSheet: Identifiable {
        case photoReview
        
        var id: Int {
            switch self {
            case .photoReview: return 1
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
                   userSettings.settings.showBodyGuidelines == true {
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
                    // Category selection - Available for all users
                    if viewModel.availableCategories.count > 1 || CategoryStorageService.shared.canAddMoreCategories() {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                ForEach(viewModel.availableCategories) { category in
                                    CategoryTabView(
                                        category: category,
                                        isSelected: viewModel.selectedCategory.id == category.id,
                                        hasPhoto: PhotoStorageService.shared.hasPhotoForToday(categoryId: category.id)
                                    ) {
                                        viewModel.selectCategory(category)
                                    }
                                }
                                
                                // Add category button
                                if CategoryStorageService.shared.canAddMoreCategories() {
                                    Button(action: {
                                        showingAddCategory = true
                                    }) {
                                        VStack(spacing: 4) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.caption.weight(.semibold))
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(Color.black.opacity(0.4))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 20)
                                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 60)
                        .padding(.bottom, 10)
                    }
                    
                    HStack {
                        // Debug date picker
                        #if DEBUG
                        if userSettings.settings.debugAllowPastDatePhotos {
                            DatePicker("", selection: $viewModel.debugSelectedDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                                .padding(.leading, 20)
                        }
                        #endif
                        
                        // Timer button
                        Menu {
                            Button(action: { viewModel.timerDuration = 0 }) {
                                Label("timer.off".localized, systemImage: viewModel.timerDuration == 0 ? "checkmark" : "")
                            }
                            Button(action: { viewModel.timerDuration = 3 }) {
                                Label("timer.3s".localized, systemImage: viewModel.timerDuration == 3 ? "checkmark" : "")
                            }
                            Button(action: { viewModel.timerDuration = 5 }) {
                                Label("timer.5s".localized, systemImage: viewModel.timerDuration == 5 ? "checkmark" : "")
                            }
                            Button(action: { viewModel.timerDuration = 10 }) {
                                Label("timer.10s".localized, systemImage: viewModel.timerDuration == 10 ? "checkmark" : "")
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                    .font(.title3)
                                if viewModel.timerDuration > 0 {
                                    Text("\(viewModel.timerDuration)s")
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(width: 60, height: 50)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 25))
                        }
                        .padding(.leading, 20)
                        
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
                    .padding(.top, (viewModel.availableCategories.count > 1) ? 0 : 60)
                    
                    if userSettings.settings.showBodyGuidelines == true {
                        BodyGuidelineView(isBodyDetected: viewModel.bodyDetected)
                    }
                    
                    // Countdown display
                    if viewModel.isCountingDown {
                        Text("\(viewModel.countdownValue)")
                            .font(.system(size: 120, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                            .transition(.scale.combined(with: .opacity))
                            .animation(.easeInOut(duration: 0.3), value: viewModel.countdownValue)
                    }
                    
                    Spacer()
                    
                    // Capture button above tab bar
                    VStack(spacing: 10) {
                        if viewModel.isCountingDown {
                            Button(action: {
                                viewModel.cancelCountdown()
                            }) {
                                Text("common.cancel".localized)
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.red.opacity(0.8))
                                    .cornerRadius(20)
                            }
                        }
                        
                        CaptureButton {
                            viewModel.capturePhoto()
                        }
                        .disabled(viewModel.isCountingDown)
                        .opacity(viewModel.isCountingDown ? 0.5 : 1.0)
                    }
                    .padding(.bottom, 20)
                }
                .ignoresSafeArea(.container, edges: .top)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("camera.access_required".localized)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("camera.access_message".localized)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    Button("camera.open_settings".localized) {
                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsURL)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            
            // Category transition overlay
            if viewModel.showingCategoryTransition, let nextCategory = viewModel.nextCategory {
                CategoryTransitionOverlay(
                    currentCategory: viewModel.selectedCategory,
                    nextCategory: nextCategory,
                    onContinue: {
                        viewModel.transitionToNextCategory()
                    },
                    onSkip: {
                        viewModel.skipCategoryTransition()
                    }
                )
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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // Stop session when app goes to background
            viewModel.stopSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Restart session when app becomes active
            if viewModel.isAuthorized {
                viewModel.restartSession()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("GuidelineUpdated"))) { notification in
            // Force refresh when guideline is updated
            viewModel.objectWillChange.send()
        }
        .alert("common.error".localized, isPresented: $viewModel.showingAlert) {
            Button("common.ok".localized, role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
        .onChange(of: viewModel.capturedImage) { _, newValue in
            if newValue != nil {
                activeSheet = .photoReview
            }
        }
        .alert("camera.one_photo_per_day".localized, isPresented: $viewModel.showingReplaceAlert) {
            Button("common.replace".localized, role: .destructive) {
                if let image = viewModel.capturedImage {
                    // Auto-display of weight input sheet is disabled - just replace the photo
                    viewModel.savePhoto(image, isReplacement: true)
                    viewModel.capturedImage = nil
                }
            }
            Button("common.cancel".localized, role: .cancel) {
                viewModel.capturedImage = nil
            }
        } message: {
            Text("camera.replace_photo_message".localized)
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
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategorySheet { newCategory in
                if CategoryStorageService.shared.addCategory(newCategory) {
                    // Set the new category for guideline setup
                    newCategoryToSetup = newCategory
                } else {
                    // Handle error - category couldn't be added
                }
            }
        }
        .fullScreenCover(item: $newCategoryToSetup) { category in
            CategoryGuidelineSetupView(category: category)
                .onDisappear {
                    // Reload categories and select the new one
                    viewModel.reloadCategories()
                    viewModel.selectCategory(category)
                }
        }
        .onAppear {
            if shouldLaunchCamera {
                // Reset the flag
                shouldLaunchCamera = false
                // Capture photo after a short delay to ensure camera is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    viewModel.capturePhoto()
                }
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
        previewLayer.videoGravity = .resizeAspect
        
        if let connection = previewLayer.connection {
            connection.videoRotationAngle = 90 // .portrait is 90 degrees
            // Only set video mirroring if automatic adjustment is disabled
            if connection.isVideoMirroringSupported && !connection.automaticallyAdjustsVideoMirroring {
                connection.isVideoMirrored = true
            }
        }
        
        view.layer.addSublayer(previewLayer)
        
        // Add pinch gesture recognizer for zoom
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handlePinchGesture(_:)))
        view.addGestureRecognizer(pinchGesture)
        
        // Ensure the layer is properly sized when the view appears
        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }
        
        return view
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(cameraViewModel: cameraViewModel)
    }
    
    class Coordinator: NSObject {
        let cameraViewModel: CameraViewModel
        private var lastZoomFactor: CGFloat = 1.0
        
        init(cameraViewModel: CameraViewModel) {
            self.cameraViewModel = cameraViewModel
        }
        
        @objc func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                lastZoomFactor = cameraViewModel.zoomFactor
            case .changed:
                let newZoomFactor = lastZoomFactor * gesture.scale
                cameraViewModel.setZoomFactor(newZoomFactor)
            case .ended, .cancelled:
                break
            default:
                break
            }
        }
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Check if we need to recreate the preview layer
        let existingPreviewLayer = uiView.layer.sublayers?.compactMap({ $0 as? AVCaptureVideoPreviewLayer }).first
        
        if existingPreviewLayer == nil || existingPreviewLayer?.session == nil {
            // Remove any existing layers and recreate
            uiView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
            
            let previewLayer = cameraViewModel.cameraPreviewLayer
            previewLayer.frame = uiView.bounds
            previewLayer.videoGravity = .resizeAspect
            
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
                
                Text(isBodyDetected ? "calendar.body_detected".localized : "calendar.align_body".localized)
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
    
    // Calculate scaled points with aspect fit logic (same as camera preview)
    private var aspectScaledContour: [CGPoint] {
        let originalSize = guideline.imageSize
        
        // Calculate scale factors for aspect fit
        let scaleX = viewSize.width / originalSize.width
        let scaleY = viewSize.height / originalSize.height
        // Use the smaller scale to ensure the content fits within the view
        let scale = min(scaleX, scaleY)
        
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
            let scaledContour = aspectScaledContour
            
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

struct CategoryTabView: View {
    let category: PhotoCategory
    let isSelected: Bool
    let hasPhoto: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(category.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                
                if hasPhoto {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 4, height: 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.bodyLapseTurquoise : Color.black.opacity(0.4))
            )
        }
    }
}


struct CategoryTransitionOverlay: View {
    let currentCategory: PhotoCategory
    let nextCategory: PhotoCategory
    let onContinue: () -> Void
    let onSkip: () -> Void
    
    @State private var isVisible = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Success icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                    .scaleEffect(isVisible ? 1 : 0.5)
                    .opacity(isVisible ? 1 : 0)
                
                VStack(spacing: 10) {
                    Text("camera.photo_saved".localized)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(currentCategory.displayName)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Arrow
                Image(systemName: "arrow.down")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.vertical, 10)
                
                // Next category
                VStack(spacing: 10) {
                    Text("camera.next_category".localized)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(nextCategory.displayName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.bodyLapseYellow)
                }
                
                // Buttons
                HStack(spacing: 20) {
                    Button(action: onSkip) {
                        Text("camera.finish_session".localized)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(25)
                    }
                    
                    Button(action: onContinue) {
                        Text("camera.continue".localized)
                            .font(.body.bold())
                            .foregroundColor(.black)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(Color.bodyLapseYellow)
                            .cornerRadius(25)
                    }
                }
                .padding(.top, 20)
            }
            .padding(40)
            .scaleEffect(isVisible ? 1 : 0.9)
            .opacity(isVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
                isVisible = true
            }
        }
    }
}

#Preview {
    CameraView()
}
