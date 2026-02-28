import SwiftUI
import AVFoundation

struct SimpleCameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onReady: ((SimpleCameraViewController) -> Void)?
    
    init(onCapture: @escaping (UIImage) -> Void, onReady: ((SimpleCameraViewController) -> Void)? = nil) {
        self.onCapture = onCapture
        self.onReady = onReady
    }
    
    func makeUIViewController(context: Context) -> SimpleCameraViewController {
        print("SimpleCameraView: makeUIViewController called")
        let controller = SimpleCameraViewController()
        controller.onCapture = onCapture
        // Delay onReady callback to avoid state modification during view update
        DispatchQueue.main.async {
            print("SimpleCameraView: Calling onReady callback")
            onReady?(controller)
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: SimpleCameraViewController, context: Context) {
        // Update if needed
    }
}

class SimpleCameraViewController: UIViewController {
    var onCapture: ((UIImage) -> Void)?
    
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private(set) var currentPosition: AVCaptureDevice.Position = .back
    
    // Timer properties
    var timerDuration: Int = 0 // 0 = off, 3, 5, 10 seconds
    private var countdownTimer: Timer?
    private var countdownValue: Int = 0
    var onCountdownUpdate: ((Int) -> Void)?
    var onCountdownComplete: (() -> Void)?
    
    // Zoom properties
    private var zoomFactor: CGFloat = 1.0
    private var minZoomFactor: CGFloat = 1.0
    private var maxZoomFactor: CGFloat = 10.0
    private var lastZoomFactor: CGFloat = 1.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("SimpleCameraViewController: viewDidLoad called")
        view.backgroundColor = .black
        checkCameraAuthorization()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Restart the capture session if it exists
        if let captureSession = captureSession, !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop the capture session when view disappears
        captureSession?.stopRunning()
    }
    
    deinit {
        // Clean up capture session
        captureSession?.stopRunning()
        captureSession = nil
    }
    
    // Force portrait orientation
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    private func checkCameraAuthorization() {
        print("SimpleCameraViewController: Checking camera authorization")
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("SimpleCameraViewController: Camera authorized, setting up")
            setupCamera()
        case .notDetermined:
            print("SimpleCameraViewController: Camera not determined, requesting access")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                print("SimpleCameraViewController: Camera access granted: \(granted)")
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                }
            }
        default:
            print("SimpleCameraViewController: Camera access denied")
        }
    }
    
    private func setupCamera() {
        print("SimpleCameraViewController: Starting camera setup")
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
        
        guard let captureSession = captureSession else { 
            print("SimpleCameraViewController: Failed to create capture session")
            return 
        }
        
        // Setup camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition) else {
            print("SimpleCameraViewController: Camera not available")
            return
        }
        print("SimpleCameraViewController: Found camera device")
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
        } catch {
            print("Error setting up camera input: \(error)")
            return
        }
        
        // Setup photo output
        photoOutput = AVCapturePhotoOutput()
        if let photoOutput = photoOutput,
           captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
        
        // Setup preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspect
        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
            previewLayer.frame = view.bounds
        }
        
        // Setup zoom factors
        setupZoomFactors(for: camera)
        
        // Add pinch gesture recognizer
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        view.addGestureRecognizer(pinchGesture)
        
        // Start session
        print("SimpleCameraViewController: Starting capture session")
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
            DispatchQueue.main.async {
                print("SimpleCameraViewController: Capture session started")
            }
        }
    }
    
    func capturePhoto() {
        guard let photoOutput = photoOutput else { return }
        
        // If timer is set, start countdown
        if timerDuration > 0 {
            startCountdown()
        } else {
            // Capture immediately
            capturePhotoNow()
        }
    }
    
    private func startCountdown() {
        countdownValue = timerDuration
        onCountdownUpdate?(countdownValue)
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.countdownValue > 1 {
                self.countdownValue -= 1
                self.onCountdownUpdate?(self.countdownValue)
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            } else {
                timer.invalidate()
                self.countdownValue = 0
                self.onCountdownUpdate?(0)
                self.onCountdownComplete?()
                self.capturePhotoNow()
            }
        }
    }
    
    func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownValue = 0
        onCountdownUpdate?(0)
    }
    
    private func capturePhotoNow() {
        guard let photoOutput = photoOutput else { return }
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func switchCamera() {
        guard let captureSession = captureSession,
              let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput else { return }
        
        captureSession.beginConfiguration()
        captureSession.removeInput(currentInput)
        
        currentPosition = currentPosition == .back ? .front : .back
        
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition) else {
            captureSession.commitConfiguration()
            return
        }
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newCamera)
            if captureSession.canAddInput(newInput) {
                captureSession.addInput(newInput)
                // Update zoom factors for the new camera
                setupZoomFactors(for: newCamera)
            }
        } catch {
            print("Error switching camera: \(error)")
        }
        
        captureSession.commitConfiguration()
    }
    
    // MARK: - ズームサポート
    
    private func setupZoomFactors(for device: AVCaptureDevice) {
        minZoomFactor = device.minAvailableVideoZoomFactor
        maxZoomFactor = min(device.maxAvailableVideoZoomFactor, 10.0) // Cap at 10x
        zoomFactor = device.videoZoomFactor
    }
    
    @objc private func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        guard let captureSession = captureSession,
              let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput else { return }
        
        let device = currentInput.device
        
        switch gesture.state {
        case .began:
            lastZoomFactor = zoomFactor
        case .changed:
            let newZoomFactor = lastZoomFactor * gesture.scale
            let clampedFactor = max(minZoomFactor, min(maxZoomFactor, newZoomFactor))
            
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clampedFactor
                device.unlockForConfiguration()
                zoomFactor = clampedFactor
            } catch {
                print("Error setting zoom factor: \(error)")
            }
        case .ended, .cancelled:
            break
        default:
            break
        }
    }
}

extension SimpleCameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else { return }
        
        onCapture?(image)
    }
}