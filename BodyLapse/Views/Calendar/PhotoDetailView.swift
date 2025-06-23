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
                            Text("Captured on")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(photo.formattedDate)
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        if photo.isFaceBlurred {
                            Label("Face Blurred", systemImage: "eye.slash.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let confidence = photo.bodyDetectionConfidence {
                        HStack {
                            Image(systemName: "figure.stand")
                                .foregroundColor(.green)
                            Text("Body detected (\(Int(confidence * 100))% confidence)")
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
            .navigationTitle("Photo Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: sharePhoto) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(role: .destructive, action: { showingDeleteAlert = true }) {
                            Label("Delete", systemImage: "trash")
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
        .alert("Delete Photo", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePhoto()
            }
        } message: {
            Text("Are you sure you want to delete this photo? This action cannot be undone.")
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