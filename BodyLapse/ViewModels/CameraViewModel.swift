import SwiftUI
import AVFoundation
import Vision

class CameraViewModel: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var showingAlert = false
    @Published var alertMessage = ""
    @Published var capturedImage: UIImage?
    @Published var bodyDetected = false
    @Published var bodyConfidence: Double = 0.0
    @Published var showingReplaceAlert = false
    @Published var showingWeightInput = false
    @Published var tempWeight: Double?
    @Published var tempBodyFat: Double?
    @Published var showGuidelines = true
    @Published var shouldBlurFace = true
    @Published var capturedPhoto: Photo?
    @Published var savedGuideline: BodyGuideline?
    @Published var selectedCategory: PhotoCategory = PhotoCategory.defaultCategory
    @Published var availableCategories: [PhotoCategory] = []
    @Published var timerDuration: Int = 0 // 0 = off, 3, 5, 10 seconds
    @Published var countdownValue: Int = 0
    @Published var isCountingDown = false
    
    // Zoom functionality
    @Published var zoomFactor: CGFloat = 1.0
    @Published var minZoomFactor: CGFloat = 1.0
    @Published var maxZoomFactor: CGFloat = 10.0
    
    // Multi-category flow
    @Published var showingCategoryTransition = false
    @Published var nextCategory: PhotoCategory?
    @Published var shouldAutoTransition = true
    
    #if DEBUG
    @Published var debugSelectedDate: Date = Date()
    #endif
    
    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var bodyDetectionRequest: VNDetectHumanBodyPoseRequest?
    @Published var currentCameraPosition: AVCaptureDevice.Position = .back
    private var currentInput: AVCaptureDeviceInput?
    private var initializationTask: Task<Void, Never>?
    
    override init() {
        super.init()
        setupBodyDetection()
        
        // Load saved guideline for default category
        loadGuidelineForCurrentCategory()
        
        // Always use Task for initialization to ensure proper actor isolation
        initializationTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            self.loadCategories()
        }
        
        // Listen for guideline updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadGuideline(_:)),
            name: Notification.Name("GuidelineUpdated"),
            object: nil
        )
        
        // Listen for category updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadCategories),
            name: Notification.Name("CategoriesUpdated"),
            object: nil
        )
    }
    
    deinit {
        initializationTask?.cancel()
        stopSession()
        cleanupPreviewLayer()
        NotificationCenter.default.removeObserver(self)
    }
    
    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupCamera()
                    }
                }
            }
        case .denied, .restricted:
            isAuthorized = false
            alertMessage = "Camera access is required to take photos. Please enable it in Settings."
            showingAlert = true
        @unknown default:
            isAuthorized = false
        }
    }
    
    @objc private func reloadGuideline(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("CameraViewModel: Received GuidelineUpdated notification")
            
            // Check if the notification is for a specific category
            if let userInfo = notification.userInfo,
               let categoryId = userInfo["categoryId"] as? String {
                print("CameraViewModel: Guideline updated for category: \(categoryId)")
                
                // Reload categories in case a new guideline was set
                self.loadCategories()
                
                // If the updated category is the current one, reload the guideline
                if categoryId == self.selectedCategory.id {
                    print("CameraViewModel: Current category matches, reloading guideline")
                    self.savedGuideline = nil
                    self.loadGuidelineForCurrentCategory()
                }
            } else {
                // No specific category, reload for current category
                print("CameraViewModel: No category specified, reloading for current category")
                self.savedGuideline = nil
                self.loadGuidelineForCurrentCategory()
            }
            
            print("CameraViewModel: Guideline reloaded: \(self.savedGuideline != nil)")
            if let guideline = self.savedGuideline {
                print("CameraViewModel: Guideline has \(guideline.points.count) points")
            }
            
            // Force UI update
            self.objectWillChange.send()
        }
    }
    
    private func setupCamera() {
        // Clean up any existing configuration
        session.beginConfiguration()
        
        // Remove existing inputs and outputs
        for input in session.inputs {
            session.removeInput(input)
        }
        for output in session.outputs {
            session.removeOutput(output)
        }
        
        session.sessionPreset = .photo
        
        // Try to get the back wide-angle camera first. If that fails (e.g. on Simulator), fall back to front camera or any available video device.
        let device: AVCaptureDevice
        if let back = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            device = back
        } else if let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            device = front
        } else if let any = AVCaptureDevice.default(for: .video) {
            device = any
        } else {
            alertMessage = "Camera not available on this device"
            showingAlert = true
            session.commitConfiguration()
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
                currentInput = input
                currentCameraPosition = device.position
                
                // Set up zoom factors
                setupZoomFactors(for: device)
            }
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            session.commitConfiguration()
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
                // Session started running
            }
        } catch {
            session.commitConfiguration()
            alertMessage = "Failed to setup camera: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func setupBodyDetection() {
        bodyDetectionRequest = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            guard let observations = request.results as? [VNHumanBodyPoseObservation],
                  let observation = observations.first else {
                DispatchQueue.main.async {
                    self?.bodyDetected = false
                    self?.bodyConfidence = 0.0
                }
                return
            }
            
            DispatchQueue.main.async {
                self?.bodyDetected = true
                self?.bodyConfidence = Double(observation.confidence)
            }
        }
    }
    
    func capturePhoto() {
        // If timer is set, start countdown
        if timerDuration > 0 {
            startCountdown()
        } else {
            // Capture immediately
            capturePhotoNow()
        }
    }
    
    private func startCountdown() {
        isCountingDown = true
        countdownValue = timerDuration
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.countdownValue > 1 {
                self.countdownValue -= 1
                // Haptic feedback for each count
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            } else {
                timer.invalidate()
                self.countdownValue = 0
                self.isCountingDown = false
                self.capturePhotoNow()
            }
        }
    }
    
    func cancelCountdown() {
        isCountingDown = false
        countdownValue = 0
    }
    
    private func capturePhotoNow() {
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
    
    @MainActor
    func checkAndSavePhoto(_ image: UIImage) {
        if hasPhotoForSelectedCategory() {
            DispatchQueue.main.async { [weak self] in
                self?.showingReplaceAlert = true
            }
        } else {
            Task { @MainActor [weak self] in
                if SubscriptionManagerService.shared.isPremium == true {
                    // Check if weight data already exists for today
                    do {
                        let hasWeightToday = try await WeightStorageService.shared.getEntry(for: Date()) != nil
                        if hasWeightToday {
                            // Weight already recorded for today, skip input screen
                            self?.savePhoto(image)
                            self?.capturedImage = nil
                        } else {
                            // No weight data for today, show input screen
                            self?.showingWeightInput = true
                        }
                    } catch {
                        // If there's an error checking, just save the photo without weight input
                        self?.savePhoto(image)
                        self?.capturedImage = nil
                    }
                } else {
                    self?.savePhoto(image)
                    self?.capturedImage = nil
                }
            }
        }
    }
    
    @MainActor
    func savePhoto(_ image: UIImage) {
        // Always save without face blur - face blur is only for video generation
        saveProcessedPhoto(image, wasBlurred: false)
    }
    
    @MainActor
    private func saveProcessedPhoto(_ image: UIImage, wasBlurred: Bool) {
        do {
            #if DEBUG
            let saveDate = UserSettingsManager.shared.settings.debugAllowPastDatePhotos ? debugSelectedDate : Date()
            #else
            let saveDate = Date()
            #endif
            
            if hasPhotoForSelectedCategory() {
                _ = try PhotoStorageService.shared.replacePhoto(
                    for: saveDate,
                    categoryId: selectedCategory.id,
                    with: image,
                    isFaceBlurred: wasBlurred,
                    bodyDetectionConfidence: bodyDetected ? bodyConfidence : nil,
                    weight: tempWeight,
                    bodyFatPercentage: tempBodyFat
                )
            } else {
                _ = try PhotoStorageService.shared.savePhoto(
                    image,
                    captureDate: saveDate,
                    categoryId: selectedCategory.id,
                    isFaceBlurred: wasBlurred,
                    bodyDetectionConfidence: bodyDetected ? bodyConfidence : nil,
                    weight: tempWeight,
                    bodyFatPercentage: tempBodyFat
                )
            }
            // Photo saved successfully
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.tempWeight = nil
                self.tempBodyFat = nil
                self.capturedImage = nil // Clear the captured image to close the sheet
                
                // Check if user is premium and there are more categories to capture
                let isPremium = SubscriptionManagerService.shared.isPremium
                if isPremium, let nextCategory = CategoryStorageService.shared.getNextUncapturedCategory(
                    for: saveDate,
                    currentCategoryId: self.selectedCategory.id,
                    isPremium: isPremium
                ) {
                    // Show transition to next category
                    self.nextCategory = nextCategory
                    self.showingCategoryTransition = true
                    
                    // Auto-transition after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if self.shouldAutoTransition && self.showingCategoryTransition {
                            self.transitionToNextCategory()
                        }
                    }
                } else {
                    // No more categories or free user - navigate to Calendar
                    // Force reload photos from disk before navigating
                    PhotoStorageService.shared.reloadPhotosFromDisk()
                    
                    // Small delay to ensure data is fully loaded
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NavigateToCalendarToday"),
                            object: nil
                        )
                    }
                }
            }
        } catch {
            // Failed to save photo
            DispatchQueue.main.async { [weak self] in
                self?.alertMessage = "Failed to save photo: \(error.localizedDescription)"
                self?.showingAlert = true
                self?.capturedImage = nil // Clear even on error
            }
        }
    }
    
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    var cameraPreviewLayer: AVCaptureVideoPreviewLayer {
        if let existingLayer = previewLayer, existingLayer.session != nil {
            return existingLayer
        }
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspect
        previewLayer = layer
        return layer
    }
    
    func stopSession() {
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.stopRunning()
                // Session stopped
            }
        }
    }
    
    func restartSession() {
        if isAuthorized {
            // If session has no inputs/outputs, set it up again
            if session.inputs.isEmpty || session.outputs.isEmpty {
                setupCamera()
            } else if !session.isRunning {
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    self?.session.startRunning()
                    // Session restarted
                }
            }
        }
    }
    
    func cleanupPreviewLayer() {
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
    }
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            DispatchQueue.main.async { [weak self] in
                self?.alertMessage = "Failed to capture photo"
                self?.showingAlert = true
            }
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.capturedImage = image
        }
    }
    
    func resetCapture() {
        capturedImage = nil
        bodyDetected = false
        bodyConfidence = 0.0
    }
    
    func switchCamera() {
        guard let currentInput = self.currentInput else { return }
        
        session.beginConfiguration()
        session.removeInput(currentInput)
        
        let newPosition: AVCaptureDevice.Position = currentCameraPosition == .front ? .back : .front
        
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            // If we can't get the new camera, add back the current one
            session.addInput(currentInput)
            session.commitConfiguration()
            return
        }
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                self.currentInput = newInput
                self.currentCameraPosition = newPosition
                
                // Set up zoom factors for the new device
                setupZoomFactors(for: newDevice)
            } else {
                // If we can't add the new input, add back the current one
                session.addInput(currentInput)
            }
        } catch {
            // If there's an error, add back the current input
            session.addInput(currentInput)
            // Error switching camera
        }
        
        session.commitConfiguration()
    }
    
    func processCapture(_ image: UIImage) {
        self.capturedImage = image
    }
    
    func cleanup() {
        initializationTask?.cancel()
        initializationTask = nil
        
        stopSession()
        cleanupPreviewLayer()
        
        // Remove all inputs and outputs from the session
        session.beginConfiguration()
        for input in session.inputs {
            session.removeInput(input)
        }
        for output in session.outputs {
            session.removeOutput(output)
        }
        session.commitConfiguration()
        
        // Clear the current input reference
        currentInput = nil
    }
    
    // MARK: - Category Support
    
    @MainActor
    private func loadCategories() {
        let isPremium = SubscriptionManagerService.shared.isPremium
        availableCategories = CategoryStorageService.shared.getActiveCategoriesForUser(isPremium: isPremium)
        
        // Update the selected category with fresh data from storage
        if let updatedCategory = availableCategories.first(where: { $0.id == selectedCategory.id }) {
            selectedCategory = updatedCategory
            print("CameraViewModel: Updated selected category with fresh data")
        } else {
            selectedCategory = availableCategories.first ?? PhotoCategory.defaultCategory
        }
    }
    
    private func loadGuidelineForCurrentCategory() {
        print("CameraViewModel: Loading guideline for category: \(selectedCategory.id)")
        savedGuideline = GuidelineStorageService.shared.loadGuideline(for: selectedCategory.id)
        print("CameraViewModel: Loaded guideline: \(savedGuideline != nil)")
        if let guideline = savedGuideline {
            print("CameraViewModel: Guideline details - points: \(guideline.points.count), imageSize: \(guideline.imageSize)")
        }
    }
    
    func selectCategory(_ category: PhotoCategory) {
        print("CameraViewModel: Selecting category: \(category.name) (ID: \(category.id))")
        selectedCategory = category
        loadGuidelineForCurrentCategory()
        // Force UI update
        objectWillChange.send()
    }
    
    @objc func reloadCategories() {
        Task { @MainActor in
            loadCategories()
            // If the selected category is no longer available, switch to default
            if !availableCategories.contains(where: { $0.id == selectedCategory.id }) {
                selectedCategory = availableCategories.first ?? PhotoCategory.defaultCategory
                loadGuidelineForCurrentCategory()
            }
        }
    }
    
    @MainActor
    func hasPhotoForSelectedCategory() -> Bool {
        #if DEBUG
        if UserSettingsManager.shared.settings.debugAllowPastDatePhotos {
            return PhotoStorageService.shared.hasPhotoForDate(debugSelectedDate, categoryId: selectedCategory.id)
        }
        #endif
        return PhotoStorageService.shared.hasPhotoForToday(categoryId: selectedCategory.id)
    }
    
    func transitionToNextCategory() {
        guard let nextCategory = nextCategory else { return }
        
        showingCategoryTransition = false
        selectedCategory = nextCategory
        loadGuidelineForCurrentCategory()
        self.nextCategory = nil
        shouldAutoTransition = true // Reset for next time
    }
    
    func skipCategoryTransition() {
        showingCategoryTransition = false
        nextCategory = nil
        shouldAutoTransition = true // Reset for next time
        
        // Navigate to Calendar
        NotificationCenter.default.post(
            name: NSNotification.Name("NavigateToCalendarToday"),
            object: nil
        )
    }
    
    // MARK: - Zoom Support
    
    private func setupZoomFactors(for device: AVCaptureDevice) {
        DispatchQueue.main.async { [weak self] in
            self?.minZoomFactor = device.minAvailableVideoZoomFactor
            self?.maxZoomFactor = min(device.maxAvailableVideoZoomFactor, 10.0) // Cap at 10x
            self?.zoomFactor = device.videoZoomFactor
        }
    }
    
    func setZoomFactor(_ factor: CGFloat) {
        guard let device = currentInput?.device else { return }
        
        let clampedFactor = max(minZoomFactor, min(maxZoomFactor, factor))
        
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clampedFactor
            device.unlockForConfiguration()
            
            DispatchQueue.main.async { [weak self] in
                self?.zoomFactor = clampedFactor
            }
        } catch {
            print("Error setting zoom factor: \(error)")
        }
    }
}