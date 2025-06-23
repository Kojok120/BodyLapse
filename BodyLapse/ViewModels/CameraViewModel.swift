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
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            alertMessage = "Front camera not available"
            showingAlert = true
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
    
    func savePhoto(_ image: UIImage) {
        do {
            let photo = try PhotoStorageService.shared.savePhoto(
                image,
                isFaceBlurred: userSettings.settings.autoFaceBlur,
                bodyDetectionConfidence: bodyDetected ? bodyConfidence : nil
            )
            print("Photo saved: \(photo.fileName)")
        } catch {
            alertMessage = "Failed to save photo: \(error.localizedDescription)"
            showingAlert = true
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
}