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
    
    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var bodyDetectionRequest: VNDetectHumanBodyPoseRequest?
    
    let userSettings = UserSettingsManager()
    
    override init() {
        super.init()
        setupBodyDetection()
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
    
    private func setupCamera() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // Try to get the front wide-angle camera first. If that fails (e.g. on Simulator or devices without front camera), fall back to any available video device.
        let device: AVCaptureDevice
        if let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            device = front
        } else if let back = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            device = back
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
            }
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            session.commitConfiguration()
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        } catch {
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
            if userSettings.settings.isPremium {
                DispatchQueue.main.async { [weak self] in
                    self?.showingWeightInput = true
                }
            } else {
                savePhoto(image)
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
            print("Photo saved: \(photo.fileName)")
            
            DispatchQueue.main.async { [weak self] in
                self?.tempWeight = nil
                self?.tempBodyFat = nil
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.alertMessage = "Failed to save photo: \(error.localizedDescription)"
                self?.showingAlert = true
            }
        }
    }
    
    var cameraPreviewLayer: AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
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
        guard let currentInput = session.inputs.first as? AVCaptureDeviceInput else { return }
        
        session.beginConfiguration()
        session.removeInput(currentInput)
        
        let currentPosition = currentInput.device.position
        let newPosition: AVCaptureDevice.Position = currentPosition == .front ? .back : .front
        
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            session.addInput(currentInput)
            session.commitConfiguration()
            return
        }
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
            }
        } catch {
            session.addInput(currentInput)
        }
        
        session.commitConfiguration()
    }
    
    func processCapture(_ image: UIImage) {
        self.capturedImage = image
    }
}