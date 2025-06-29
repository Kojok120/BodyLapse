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
    @State private var itemToShare: Any?
    @State private var showingShareSheet = false
    
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
            .navigationTitle("gallery.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.loadData()
                checkForVideoToPlay()
            }
            .onChange(of: videoToPlay) { _, newValue in
                checkForVideoToPlay()
            }
            .sheet(item: $selectedPhoto) { photo in
                PhotoDetailSheet(photo: photo)
            }
            .fullScreenCover(item: $selectedVideo) { video in
                VideoPlayerView(video: video)
            }
            .alert("gallery.delete_item".localized, isPresented: $showingDeleteAlert) {
                Button("common.delete".localized, role: .destructive) {
                    deleteSelectedItem()
                }
                Button("common.cancel".localized, role: .cancel) { }
            } message: {
                Text("gallery.delete_confirm".localized)
            }
            .overlay(alignment: .top) {
                if showingSaveSuccess {
                    saveSuccessToast
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(), value: showingSaveSuccess)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let items = itemToShare as? [Any] {
                    ShareSheet(activityItems: items)
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
                Text(section == .videos ? "gallery.videos".localized : "gallery.photos".localized)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
    }
    
    private var photosSection: some View {
        ScrollView {
            if viewModel.photos.isEmpty {
                emptyStateView(message: "gallery.no_photos".localized, icon: "photo")
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
                                    } onShare: {
                                        sharePhoto(photo)
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                            
                            // Add divider between month sections
                            if viewModel.photosGroupedByMonth().last?.0 != month {
                                Divider()
                                    .background(Color.bodyLapseLightGray)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var videosSection: some View {
        ScrollView {
            if viewModel.videos.isEmpty {
                emptyStateView(message: "gallery.no_videos".localized, icon: "video")
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
                                    } onShare: {
                                        shareVideo(video)
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                            
                            // Add divider between month sections
                            if viewModel.videosGroupedByMonth().last?.0 != month {
                                Divider()
                                    .background(Color.bodyLapseLightGray)
                                    .padding(.vertical, 8)
                            }
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
                showSaveSuccess(message: "gallery.photo_saved".localized)
            } else {
                print("Failed to save photo: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    private func saveVideo(_ video: Video) {
        viewModel.saveVideoToLibrary(video) { success, error in
            if success {
                showSaveSuccess(message: "gallery.video_saved".localized)
            } else {
                print("Failed to save video: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    private func sharePhoto(_ photo: Photo) {
        guard let image = PhotoStorageService.shared.loadImage(for: photo) else { return }
        itemToShare = [image]
        showingShareSheet = true
    }
    
    private func shareVideo(_ video: Video) {
        itemToShare = [video.fileURL]
        showingShareSheet = true
    }
}

struct PhotoGridItem: View {
    let photo: Photo
    let onTap: () -> Void
    let onDelete: () -> Void
    let onSave: () -> Void
    let onShare: () -> Void
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
                                onShare()
                            } label: {
                                Label("common.share".localized, systemImage: "square.and.arrow.up")
                            }
                            
                            Button {
                                onSave()
                            } label: {
                                Label("gallery.save_to_photos".localized, systemImage: "square.and.arrow.down")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                onDelete()
                            } label: {
                                Label("common.delete".localized, systemImage: "trash")
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
                        Spacer()
                        Menu {
                            Button {
                                onShare()
                            } label: {
                                Label("common.share".localized, systemImage: "square.and.arrow.up")
                            }
                            
                            Button {
                                onSave()
                            } label: {
                                Label("gallery.save_to_photos".localized, systemImage: "square.and.arrow.down")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                onDelete()
                            } label: {
                                Label("common.delete".localized, systemImage: "trash")
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
    @StateObject private var userSettings = UserSettingsManager.shared
    @StateObject private var subscriptionManager = SubscriptionManagerService.shared
    @State private var showingShareSheet = false
    
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
                        if let image = PhotoStorageService.shared.loadImage(for: photo) {
                            showingShareSheet = true
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
            .sheet(isPresented: $showingShareSheet) {
                if let image = PhotoStorageService.shared.loadImage(for: photo) {
                    ShareSheet(activityItems: [image])
                }
            }
        }
    }
}

struct VideoPlayerView: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var showingShareSheet = false
    
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
                        Label("\(video.frameCount) " + "gallery.photos_count".localized, systemImage: "photo.stack")
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingShareSheet = true
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
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: [video.fileURL])
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
