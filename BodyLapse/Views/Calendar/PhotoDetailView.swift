import SwiftUI

struct PhotoDetailView: View {
    let photo: Photo
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            VStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .background(Color.black)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(UIColor.systemBackground))
                }
                
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("photo.captured_on".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(photo.formattedDate)
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        if photo.isFaceBlurred {
                            Label("camera.face_blurred".localized, systemImage: "eye.slash.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let confidence = photo.bodyDetectionConfidence {
                        HStack {
                            Image(systemName: "figure.stand")
                                .foregroundColor(.green)
                            Text(String(format: "photo.body_detected".localized, Int(confidence * 100)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(15)
                .padding()
            }
            .navigationTitle("photo.details".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: sharePhoto) {
                            Label("common.share".localized, systemImage: "square.and.arrow.up")
                        }
                        
                        Button(role: .destructive, action: { showingDeleteAlert = true }) {
                            Label("common.delete".localized, systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            loadImage()
        }
        .alert("photo.delete_title".localized, isPresented: $showingDeleteAlert) {
            Button("common.cancel".localized, role: .cancel) { }
            Button("common.delete".localized, role: .destructive) {
                deletePhoto()
            }
        } message: {
            Text("photo.delete_message".localized)
        }
    }
    
    private func loadImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedImage = PhotoStorageService.shared.loadImage(for: photo)
            DispatchQueue.main.async {
                self.image = loadedImage
            }
        }
    }
    
    private func sharePhoto() {
        guard let image = image else { return }
        
        let activityController = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityController, animated: true)
        }
    }
    
    private func deletePhoto() {
        do {
            try PhotoStorageService.shared.deletePhoto(photo)
            dismiss()
        } catch {
            print("Failed to delete photo: \(error)")
        }
    }
}