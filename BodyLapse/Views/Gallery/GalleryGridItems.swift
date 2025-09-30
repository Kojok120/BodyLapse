import SwiftUI

// MARK: - Photo Grid Item

struct PhotoGridItem: View {
    let photo: Photo
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onSave: () -> Void
    let onShare: () -> Void
    @State private var image: UIImage?
    @State private var lastLoadedSize: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(UIColor.systemGray5))
                        .overlay(
                            ProgressView()
                        )
                }
                
                VStack {
                    HStack {
                        // Date label in top-left corner
                        Text(GalleryUtilities.formatDate(photo.captureDate))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                            .padding(8)
                        
                        Spacer()
                        
                        if isSelectionMode && isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.bodyLapseTurquoise)
                                .background(Circle().fill(Color.white))
                                .padding(8)
                        }
                    }
                    Spacer()
                }
                
                // Selection overlay
                if isSelectionMode && isSelected {
                    Rectangle()
                        .fill(Color.bodyLapseTurquoise.opacity(0.3))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            .onAppear {
                loadImage(for: geometry.size)
            }
            .onDisappear {
                if !isSelectionMode {
                    image = nil
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .contextMenu {
            if !isSelectionMode {
                Button {
                    if let image = image {
                        UIPasteboard.general.image = image
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                } label: {
                    Label("common.copy".localized, systemImage: "doc.on.doc")
                }
                
                Button {
                    onShare()
                } label: {
                    Label("common.share".localized, systemImage: "square.and.arrow.up")
                }
                
                Button {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    onSave()
                } label: {
                    Label("gallery.save_to_photos".localized, systemImage: "square.and.arrow.down")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    onDelete()
                } label: {
                    Label("common.delete".localized, systemImage: "trash")
                }
            }
        } preview: {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 300)
            }
        }
    }
    
    private func loadImage(for size: CGSize) {
        let clampedSize = CGSize(width: max(size.width, 1), height: max(size.height, 1))
        if image != nil && abs(clampedSize.width - lastLoadedSize.width) < 1 && abs(clampedSize.height - lastLoadedSize.height) < 1 {
            return
        }
        lastLoadedSize = clampedSize
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedImage = PhotoStorageService.shared.loadImage(for: photo, targetSize: clampedSize)
            DispatchQueue.main.async {
                self.image = loadedImage
            }
        }
    }
}

// MARK: - Video Grid Item

struct VideoGridItem: View {
    let video: Video
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onSave: () -> Void
    let onShare: () -> Void
    @State private var thumbnail: UIImage?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(UIColor.systemGray5))
                        .overlay(
                            Image(systemName: "video")
                                .font(.system(size: 30))
                                .foregroundColor(.gray)
                        )
                }
                
                VStack {
                    HStack {
                        // Date label in top-left corner
                        Text(GalleryUtilities.formatDate(video.createdDate))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                            .padding(8)
                        
                        Spacer()
                        
                        if isSelectionMode && isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.bodyLapseTurquoise)
                                .background(Circle().fill(Color.white))
                                .padding(8)
                        }
                    }
                    
                    Spacer()
                    
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text(video.formattedDuration)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                    }
                    .padding(8)
                }
                
                // Selection overlay
                if isSelectionMode && isSelected {
                    Rectangle()
                        .fill(Color.bodyLapseTurquoise.opacity(0.3))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            .onAppear {
                loadThumbnail()
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .contextMenu {
            if !isSelectionMode {
                Button {
                    onTap()
                } label: {
                    Label("gallery.play".localized, systemImage: "play.circle")
                }
                
                Button {
                    onShare()
                } label: {
                    Label("common.share".localized, systemImage: "square.and.arrow.up")
                }
                
                Button {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    onSave()
                } label: {
                    Label("gallery.save_to_photos".localized, systemImage: "square.and.arrow.down")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    onDelete()
                } label: {
                    Label("common.delete".localized, systemImage: "trash")
                }
            }
        } preview: {
            if let thumbnail = thumbnail {
                VStack {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 300)
                    
                    Text("\(video.frameCount) photos • \(video.formattedDuration)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
    }
    
    private func loadThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedThumbnail = VideoStorageService.shared.loadThumbnail(for: video)
            DispatchQueue.main.async {
                self.thumbnail = loadedThumbnail
            }
        }
    }
}
