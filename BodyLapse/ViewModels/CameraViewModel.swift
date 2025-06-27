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
    
    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var bodyDetectionRequest: VNDetectHumanBodyPoseRequest?
    @Published var currentCameraPosition: AVCaptureDevice.Position = .back
    private var currentInput: AVCaptureDeviceInput?
    var userSettings: UserSettingsManager?
    
    override init() {
        super.init()
        setupBodyDetection()
        
        // Load saved guideline
        savedGuideline = GuidelineStorageService.shared.loadGuideline()
        
        // Initialize UserSettingsManager on main queue
        Task { @MainActor in
            self.userSettings = UserSettingsManager()
        }
        
        // Listen for guideline updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadGuideline),
            name: Notification.Name("GuidelineUpdated"),
            object: nil
        )
    }
    
    deinit {
        stopSession()
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
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
    
    @objc private func reloadGuideline() {
        DispatchQueue.main.async { [weak self] in
            self?.savedGuideline = GuidelineStorageService.shared.loadGuideline()
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
            }
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            session.commitConfiguration()
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
                print("[Camera] Session started running")
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
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
    
    func checkAndSavePhoto(_ image: UIImage) {
        if PhotoStorageService.shared.hasPhotoForToday() {
            DispatchQueue.main.async { [weak self] in
                self?.showingReplaceAlert = true
            }
        } else {
            Task { @MainActor [weak self] in
                if self?.userSettings?.settings.isPremium == true {
                    self?.showingWeightInput = true
                } else {
                    self?.savePhoto(image)
                    self?.capturedImage = nil
                }
            }
        }
    }
    
    func savePhoto(_ image: UIImage) {
        // Always save without face blur - face blur is only for video generation
        saveProcessedPhoto(image, wasBlurred: false)
    }
    
    private func saveProcessedPhoto(_ image: UIImage, wasBlurred: Bool) {
        do {
            let photo: Photo
            if PhotoStorageService.shared.hasPhotoForToday() {
                photo = try PhotoStorageService.shared.replacePhoto(
                    for: Date(),
                    with: image,
                    isFaceBlurred: wasBlurred,
                    bodyDetectionConfidence: bodyDetected ? bodyConfidence : nil,
                    weight: tempWeight,
                    bodyFatPercentage: tempBodyFat
                )
            } else {
                photo = try PhotoStorageService.shared.savePhoto(
                    image,
                    isFaceBlurred: wasBlurred,
                    bodyDetectionConfidence: bodyDetected ? bodyConfidence : nil,
                    weight: tempWeight,
                    bodyFatPercentage: tempBodyFat
                )
            }
            print("[Camera] Photo saved successfully: \(photo.fileName)")
            
            DispatchQueue.main.async { [weak self] in
                self?.tempWeight = nil
                self?.tempBodyFat = nil
                self?.capturedImage = nil // Clear the captured image to close the sheet
                print("[Camera] Cleared captured image")
                
                // Navigate to Calendar with today's date
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToCalendarToday"),
                    object: nil
                )
            }
        } catch {
            print("[Camera] Failed to save photo: \(error)")
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
        layer.videoGravity = .resizeAspectFill
        previewLayer = layer
        return layer
    }
    
    func stopSession() {
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.stopRunning()
                print("[Camera] Session stopped")
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
                    print("[Camera] Session restarted")
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
            } else {
                // If we can't add the new input, add back the current one
                session.addInput(currentInput)
            }
        } catch {
            // If there's an error, add back the current input
            session.addInput(currentInput)
            print("Error switching camera: \(error)")
        }
        
        session.commitConfiguration()
    }
    
    func processCapture(_ image: UIImage) {
        self.capturedImage = image
    }
    
    func cleanup() {
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
}