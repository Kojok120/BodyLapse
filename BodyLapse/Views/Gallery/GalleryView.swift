import SwiftUI
import AVKit

struct GalleryView: View {
    @Binding var videoToPlay: UUID?
    @StateObject private var viewModel = GalleryViewModel()
    @State private var selectedPhoto: Photo?
    @State private var selectedVideo: Video?
    @State private var showingDeleteAlert = false
    @State private var itemToDelete: Any?
    @State private var showingSaveSuccess = false
    @State private var saveSuccessMessage = ""
    
    init(videoToPlay: Binding<UUID?> = .constant(nil)) {
        self._videoToPlay = videoToPlay
    }
    
    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                sectionPicker
                
                TabView(selection: $viewModel.selectedSection) {
                    videosSection
                        .tag(GalleryViewModel.GallerySection.videos)
                    
                    photosSection
                        .tag(GalleryViewModel.GallerySection.photos)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .withBannerAd()
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.loadData()
                checkForVideoToPlay()
            }
            .onChange(of: videoToPlay) { newValue in
                checkForVideoToPlay()
            }
            .sheet(item: $selectedPhoto) { photo in
                PhotoDetailSheet(photo: photo)
            }
            .fullScreenCover(item: $selectedVideo) { video in
                VideoPlayerView(video: video)
            }
            .alert("Delete Item", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    deleteSelectedItem()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this item? This action cannot be undone.")
            }
            .overlay(alignment: .top) {
                if showingSaveSuccess {
                    saveSuccessToast
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(), value: showingSaveSuccess)
                }
            }
        }
    }
    
    private func checkForVideoToPlay() {
        if let videoId = videoToPlay {
            print("[GalleryView] Checking for video to play: \(videoId)")
            // Find the video and play it
            if let video = viewModel.videos.first(where: { $0.id == videoId }) {
                print("[GalleryView] Found video to play: \(video.fileName)")
                viewModel.selectedSection = .videos
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    selectedVideo = video
                    videoToPlay = nil // Clear after playing
                }
            } else {
                print("[GalleryView] Video not found in list. Total videos: \(viewModel.videos.count)")
            }
        }
    }
    
    private var sectionPicker: some View {
        Picker("Section", selection: $viewModel.selectedSection) {
            ForEach(GalleryViewModel.GallerySection.allCases, id: \.self) { section in
                Text(section.rawValue)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
    }
    
    private var photosSection: some View {
        ScrollView {
            if viewModel.photos.isEmpty {
                emptyStateView(message: "No photos yet", icon: "photo")
            } else {
                LazyVStack(pinnedViews: .sectionHeaders) {
                    ForEach(viewModel.photosGroupedByMonth(), id: \.0) { month, photos in
                        Section(header: sectionHeader(title: month)) {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(photos) { photo in
                                    PhotoGridItem(photo: photo) {
                                        selectedPhoto = photo
                                    } onDelete: {
                                        itemToDelete = photo
                                        showingDeleteAlert = true
                                    } onSave: {
                                        savePhoto(photo)
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                }
            }
        }
    }
    
    private var videosSection: some View {
        ScrollView {
            if viewModel.videos.isEmpty {
                emptyStateView(message: "No videos yet", icon: "video")
            } else {
                LazyVStack(pinnedViews: .sectionHeaders) {
                    ForEach(viewModel.videosGroupedByMonth(), id: \.0) { month, videos in
                        Section(header: sectionHeader(title: month)) {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(videos) { video in
                                    VideoGridItem(video: video) {
                                        selectedVideo = video
                                    } onDelete: {
                                        itemToDelete = video
                                        showingDeleteAlert = true
                                    } onSave: {
                                        saveVideo(video)
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                }
            }
        }
    }
    
    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground).opacity(0.95))
    }
    
    private func emptyStateView(message: String, icon: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private func deleteSelectedItem() {
        if let photo = itemToDelete as? Photo {
            viewModel.deletePhoto(photo)
        } else if let video = itemToDelete as? Video {
            viewModel.deleteVideo(video)
        }
        itemToDelete = nil
    }
    
    private var saveSuccessToast: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
            
            Text(saveSuccessMessage)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding(.top, 50)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showingSaveSuccess = false
                }
            }
        }
    }
    
    private func showSaveSuccess(message: String) {
        saveSuccessMessage = message
        withAnimation {
            showingSaveSuccess = true
        }
    }
    
    private func savePhoto(_ photo: Photo) {
        viewModel.savePhotoToLibrary(photo) { success, error in
            if success {
                showSaveSuccess(message: "Photo saved to library")
            } else {
                print("Failed to save photo: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    private func saveVideo(_ video: Video) {
        viewModel.saveVideoToLibrary(video) { success, error in
            if success {
                showSaveSuccess(message: "Video saved to library")
            } else {
                print("Failed to save video: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
}

struct PhotoGridItem: View {
    let photo: Photo
    let onTap: () -> Void
    let onDelete: () -> Void
    let onSave: () -> Void
    @State private var image: UIImage?
    
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
                        Spacer()
                        Menu {
                            Button {
                                onSave()
                            } label: {
                                Label("Save to Photos", systemImage: "square.and.arrow.down")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                onDelete()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .padding(8)
                    }
                    Spacer()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            .onAppear {
                loadImage()
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func loadImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedImage = PhotoStorageService.shared.loadImage(for: photo)
            DispatchQueue.main.async {
                self.image = loadedImage
            }
        }
    }
}

struct VideoGridItem: View {
    let video: Video
    let onTap: () -> Void
    let onDelete: () -> Void
    let onSave: () -> Void
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
                        Spacer()
                        Menu {
                            Button {
                                onSave()
                            } label: {
                                Label("Save to Photos", systemImage: "square.and.arrow.down")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                onDelete()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .padding(8)
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
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            .onAppear {
                loadThumbnail()
            }
        }
        .aspectRatio(1, contentMode: .fit)
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

struct PhotoDetailSheet: View {
    let photo: Photo
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userSettings = UserSettingsManager()
    
    var body: some View {
        NavigationView {
            VStack {
                if let image = PhotoStorageService.shared.loadImage(for: photo) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text(photo.formattedDate)
                            .font(.headline)
                        
                        if userSettings.settings.isPremium {
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
                            Label("Face blurred", systemImage: "eye.slash")
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct VideoPlayerView: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    
    var body: some View {
        NavigationView {
            VStack {
                if let player = player {
                    VideoPlayer(player: player)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(video.dateRangeText)
                        .font(.headline)
                    
                    HStack {
                        Label("\(video.frameCount) photos", systemImage: "photo.stack")
                        Spacer()
                        Label(video.formattedDuration, systemImage: "timer")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupPlayer()
            }
            .onDisappear {
                player?.pause()
            }
        }
    }
    
    private func setupPlayer() {
        player = AVPlayer(url: video.fileURL)
        player?.play()
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { _ in
            player?.seek(to: .zero)
            player?.play()
        }
    }
}