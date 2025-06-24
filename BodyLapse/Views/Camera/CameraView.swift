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
        .sheet(isPresented: .constant(viewModel.capturedImage != nil)) {
            if let image = viewModel.capturedImage {
                PhotoReviewView(
                    image: image,
                    onSave: { image in
                        viewModel.checkAndSavePhoto(image)
                    },
                    onCancel: {
                        viewModel.capturedImage = nil
                    }
                )
            }
        }
        .alert("Only One Photo Per Day", isPresented: $viewModel.showingReplaceAlert) {
            Button("Replace", role: .destructive) {
                if let image = viewModel.capturedImage {
                    if viewModel.userSettings.settings.isPremium {
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
        .sheet(isPresented: $viewModel.showingWeightInput) {
            WeightInputSheet(
                weight: $viewModel.tempWeight,
                bodyFat: $viewModel.tempBodyFat,
                onSave: {
                    if let image = viewModel.capturedImage {
                        viewModel.savePhoto(image)
                        viewModel.capturedImage = nil
                    }
                },
                onCancel: {
                    viewModel.capturedImage = nil
                    viewModel.tempWeight = nil
                    viewModel.tempBodyFat = nil
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
        if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
            if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
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

// Remove UIImage Identifiable extension as it's not needed

struct WeightInputSheet: View {
    @Binding var weight: Double?
    @Binding var bodyFat: Double?
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userSettings = UserSettingsManager()
    @State private var weightText = ""
    @State private var bodyFatText = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Measurements (Optional)")) {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("0.0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text(userSettings.settings.weightUnit.symbol)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Body Fat")
                        Spacer()
                        TextField("0.0", text: $bodyFatText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("%")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Text("You can add or update these measurements later from the Progress tab")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Measurements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Skip") {
                        onSave()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        weight = Double(weightText)
                        bodyFat = Double(bodyFatText)
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}