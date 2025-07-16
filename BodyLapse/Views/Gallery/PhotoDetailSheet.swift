import SwiftUI

struct PhotoDetailSheet: View {
    let photo: Photo
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userSettings = UserSettingsManager.shared
    @StateObject private var subscriptionManager = SubscriptionManagerService.shared
    @State private var activeSheet: GalleryActiveSheet?
    
    // Zoom functionality state
    @State private var currentScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var currentOffset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        NavigationView {
            VStack {
                if let image = PhotoStorageService.shared.loadImage(for: photo) {
                    GeometryReader { geometry in
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .scaleEffect(currentScale)
                            .offset(currentOffset)
                            .clipped()
                            .gesture(
                                SimultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            currentScale = lastScale * value
                                        }
                                        .onEnded { value in
                                            lastScale = currentScale
                                            // Reset if scale is too small
                                            if currentScale < 1.0 {
                                                withAnimation(.spring()) {
                                                    currentScale = 1.0
                                                    lastScale = 1.0
                                                    currentOffset = .zero
                                                    lastOffset = .zero
                                                }
                                            }
                                        },
                                    
                                    DragGesture()
                                        .onChanged { value in
                                            // Only allow drag when zoomed in
                                            if currentScale > 1.0 {
                                                currentOffset = CGSize(
                                                    width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height
                                                )
                                            }
                                        }
                                        .onEnded { value in
                                            lastOffset = currentOffset
                                            
                                            // Limit the offset to prevent image from going too far
                                            let maxOffsetX = (geometry.size.width * (currentScale - 1)) / 2
                                            let maxOffsetY = (geometry.size.height * (currentScale - 1)) / 2
                                            
                                            let constrainedOffset = CGSize(
                                                width: min(maxOffsetX, max(-maxOffsetX, currentOffset.width)),
                                                height: min(maxOffsetY, max(-maxOffsetY, currentOffset.height))
                                            )
                                            
                                            if constrainedOffset != currentOffset {
                                                withAnimation(.spring()) {
                                                    currentOffset = constrainedOffset
                                                    lastOffset = constrainedOffset
                                                }
                                            }
                                        }
                                )
                            )
                            .onTapGesture(count: 2) {
                                // Double tap to reset zoom
                                withAnimation(.spring()) {
                                    currentScale = 1.0
                                    lastScale = 1.0
                                    currentOffset = .zero
                                    lastOffset = .zero
                                }
                            }
                    }
                    .frame(maxHeight: .infinity)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text(photo.formattedDate)
                            .font(.headline)
                        
                        if subscriptionManager.isPremium {
                            HStack {
                                if let weight = photo.weight {
                                    Label("\(String(format: "%.1f", weight)) \(userSettings.settings.weightUnit.symbol)", systemImage: "scalemass")
                                        .font(.subheadline)
                                }
                                
                                if let bodyFat = photo.bodyFatPercentage {
                                    Label("\(String(format: "%.1f", bodyFat))%", systemImage: "percent")
                                        .font(.subheadline)
                                }
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        if photo.isFaceBlurred {
                            Label("camera.face_blurred".localized, systemImage: "eye.slash")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if PhotoStorageService.shared.loadImage(for: photo) != nil {
                            activeSheet = .shareOptions(photo)
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .shareOptions(let photo):
                    ShareOptionsDialog(
                        photo: photo,
                        onDismiss: {
                            activeSheet = nil
                        },
                        onShare: handlePhotoShare
                    )
                case .share(let items):
                    ShareSheet(activityItems: items) {
                        activeSheet = nil
                    }
                }
            }
        }
    }
    
    private func handlePhotoShare(_ image: UIImage, withFaceBlur: Bool) {
        activeSheet = .share([image])
    }
}