import SwiftUI

struct PhotoCaptureView: View {
    @StateObject private var userSettings = UserSettingsManager.shared
    @StateObject private var subscriptionManager = SubscriptionManagerService.shared
    @State private var showingReplaceAlert = false
    @State private var pendingPhoto: UIImage?
    @State private var capturedPhoto: Photo?
    @State private var showGuidelines = true
    @State private var cameraController: SimpleCameraViewController?
    
    var body: some View {
        NavigationView {
            ZStack {
                SimpleCameraView { image in
                    handlePhotoCapture(image)
                } onReady: { controller in
                    cameraController = controller
                }
                .edgesIgnoringSafeArea(.all)
                
                if showGuidelines {
                    GuidelineOverlay()
                }
                
                VStack {
                    Spacer()
                    
                    controlPanel
                        .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
            .alert("photo.replace_today_title".localized, isPresented: $showingReplaceAlert) {
                Button("Cancel", role: .cancel) {
                    pendingPhoto = nil
                }
                Button("common.replace".localized) {
                    if let image = pendingPhoto {
                        savePhoto(image, isReplacement: true)
                    }
                }
            } message: {
                Text("photo.replace_today_message".localized)
            }
        }
    }
    
    private var controlPanel: some View {
        VStack(spacing: 20) {
            HStack(spacing: 40) {
                // ガイドライントグル
                Button(action: {
                    showGuidelines.toggle()
                }) {
                    VStack {
                        Image(systemName: showGuidelines ? "person.fill" : "person")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text("photo.guidelines".localized)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                
                // カメラ切り替え
                Button(action: {
                    cameraController?.switchCamera()
                }) {
                    VStack {
                        Image(systemName: "camera.rotate")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text("photo.switch_camera".localized)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
            }
            
            // 撮影ボタン
            Button(action: {
                cameraController?.capturePhoto()
            }) {
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
        .padding()
        .background(
            Color.black.opacity(0.3)
                .blur(radius: 10)
                .ignoresSafeArea()
        )
    }
    
    private func handlePhotoCapture(_ image: UIImage) {
        if PhotoStorageService.shared.hasPhotoForToday() {
            pendingPhoto = image
            showingReplaceAlert = true
        } else {
            savePhoto(image, isReplacement: false)
        }
    }
    
    private func savePhoto(_ image: UIImage, isReplacement: Bool) {
        do {
            let photo: Photo
            if isReplacement {
                photo = try PhotoStorageService.shared.replacePhoto(
                    for: Date(),
                    with: image,
                    isFaceBlurred: false
                )
            } else {
                photo = try PhotoStorageService.shared.savePhoto(
                    image,
                    isFaceBlurred: false
                )
            }
            
            capturedPhoto = photo
            
            // 体重入力シートの自動表示は無効
            
        } catch {
            print("Failed to save photo: \(error)")
        }
    }
}

struct PhotoWeightInputView: View {
    let photo: Photo
    let onSave: (Double?, Double?) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userSettings = UserSettingsManager.shared
    
    @State private var weightText = ""
    @State private var bodyFatText = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("photo.add_measurements_optional".localized)) {
                    HStack {
                        Text("calendar.weight".localized)
                        Spacer()
                        TextField("photo.enter_value".localized, text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text(userSettings.settings.weightUnit.symbol)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("photo.body_fat".localized)
                        Spacer()
                        TextField("photo.enter_value".localized, text: $bodyFatText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("%")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Text("photo.measurements_note".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("nav.photo_saved".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.skip".localized) {
                        onSave(nil, nil)
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.save".localized) {
                        var weightInKg: Double? = nil
                        if let weight = Double(weightText) {
                            // ユーザーがlbs使用の場合kgに変換
                            weightInKg = userSettings.settings.weightUnit == .kg ? weight : weight / 2.20462
                        }
                        let bodyFat = Double(bodyFatText)
                        onSave(weightInKg, bodyFat)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct GuidelineOverlay: View {
    @State private var guideline: BodyGuideline? = GuidelineStorageService.shared.loadGuideline()
    
    var body: some View {
        GeometryReader { geometry in
            if let guideline = guideline {
                // カメラプレビューに合わせたアスペクトフィットスケーリングで保存済みボディコンターを表示
                let scaledPoints = aspectFitScaledPoints(
                    guideline: guideline,
                    viewSize: geometry.size
                )
                
                Path { path in
                    guard scaledPoints.count > 2 else { return }
                    
                    path.move(to: scaledPoints[0])
                    for i in 1..<scaledPoints.count {
                        path.addLine(to: scaledPoints[i])
                    }
                    path.closeSubpath()
                }
                .stroke(Color.yellow.opacity(0.6), lineWidth: 2)
                .shadow(color: .black, radius: 2)
            } else {
                // 保存済みガイドラインなし、汎用ボディアウトラインを表示
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let centerX = width / 2
                    
                    // 頭部の円
                    path.addEllipse(in: CGRect(
                        x: centerX - 30,
                        y: height * 0.15 - 30,
                        width: 60,
                        height: 60
                    ))
                    
                    // ボディアウトライン
                    path.move(to: CGPoint(x: centerX - 50, y: height * 0.25))
                    path.addLine(to: CGPoint(x: centerX - 40, y: height * 0.35))
                    path.addLine(to: CGPoint(x: centerX - 60, y: height * 0.55))
                    path.addLine(to: CGPoint(x: centerX - 40, y: height * 0.75))
                    path.addLine(to: CGPoint(x: centerX - 30, y: height * 0.85))
                    
                    path.move(to: CGPoint(x: centerX + 50, y: height * 0.25))
                    path.addLine(to: CGPoint(x: centerX + 40, y: height * 0.35))
                    path.addLine(to: CGPoint(x: centerX + 60, y: height * 0.55))
                    path.addLine(to: CGPoint(x: centerX + 40, y: height * 0.75))
                    path.addLine(to: CGPoint(x: centerX + 30, y: height * 0.85))
                    
                    // 腕
                    path.move(to: CGPoint(x: centerX - 40, y: height * 0.3))
                    path.addLine(to: CGPoint(x: centerX - 70, y: height * 0.45))
                    
                    path.move(to: CGPoint(x: centerX + 40, y: height * 0.3))
                    path.addLine(to: CGPoint(x: centerX + 70, y: height * 0.45))
                }
                .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
            }
        }
    }
    
    // カメラプレビューに合わせたアスペクトフィットロジックでガイドラインポイントをスケーリングするヘルパー関数
    private func aspectFitScaledPoints(guideline: BodyGuideline, viewSize: CGSize) -> [CGPoint] {
        let originalSize = guideline.imageSize
        
        // アスペクトフィットのスケール係数を計算
        let scaleX = viewSize.width / originalSize.width
        let scaleY = viewSize.height / originalSize.height
        // コンテンツがビュー内に収まるように小さい方のスケールを使用
        let scale = min(scaleX, scaleY)
        
        // スケーリング後のサイズを計算
        let scaledWidth = originalSize.width * scale
        let scaledHeight = originalSize.height * scale
        
        // スケーリングされたコンテンツを中央に配置するオフセットを計算
        let offsetX = (viewSize.width - scaledWidth) / 2
        let offsetY = (viewSize.height - scaledHeight) / 2
        
        // Apply scale and offset to guideline points
        return guideline.points.map { point in
            CGPoint(
                x: point.x * scale + offsetX,
                y: point.y * scale + offsetY
            )
        }
    }
}