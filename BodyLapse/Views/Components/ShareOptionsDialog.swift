import SwiftUI
import Foundation

struct ShareOptionsDialog: View {
    let photo: Photo
    let onDismiss: () -> Void
    let onShare: (UIImage, Bool) -> Void
    
    @State private var isProcessing = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("share.options.title".localized)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("share.options.description".localized)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // Options
                VStack(spacing: 12) {
                    // Share without face blur
                    ShareOptionButton(
                        title: "share.options.normal".localized,
                        subtitle: "share.options.normal.description".localized,
                        icon: "square.and.arrow.up",
                        color: .blue,
                        isProcessing: isProcessing
                    ) {
                        sharePhoto(withFaceBlur: false)
                    }
                    
                    // Share with face blur
                    ShareOptionButton(
                        title: "share.options.blur".localized,
                        subtitle: "share.options.blur.description".localized,
                        icon: "face.dashed",
                        color: .green,
                        isProcessing: isProcessing
                    ) {
                        sharePhoto(withFaceBlur: true)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                
                Spacer()
            }
            .navigationTitle("share.options.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.cancel".localized) {
                        onDismiss()
                    }
                }
            }
            .background(Color(.systemBackground))
        }
        .alert("share.error.title".localized, isPresented: $showingError) {
            Button("common.ok".localized, role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func sharePhoto(withFaceBlur: Bool) {
        guard let image = PhotoStorageService.shared.loadImage(for: photo) else {
            showError("share.error.load_failed".localized)
            return
        }
        
        if withFaceBlur {
            isProcessing = true
            
            Task {
                let userSettings = await UserSettingsManager.shared
                let blurMethod = await userSettings.settings.faceBlurMethod.toServiceMethod
                let processedImage = await FaceBlurService.shared.processImageAsync(image, blurMethod: blurMethod)
                
                await MainActor.run {
                    isProcessing = false
                    onShare(processedImage, true)
                }
            }
        } else {
            onShare(image, false)
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

struct ShareOptionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isProcessing: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .disabled(isProcessing)
    }
}

#Preview {
    ShareOptionsDialog(
        photo: Photo(
            id: UUID(),
            captureDate: Date(),
            fileName: "test.jpg",
            categoryId: "front",
            weight: nil,
            bodyFatPercentage: nil
        ),
        onDismiss: {},
        onShare: { _, _ in }
    )
}