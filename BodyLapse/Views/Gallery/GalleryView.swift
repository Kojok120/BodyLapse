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
    @State private var showingBulkDeleteAlert = false
    @State private var currentGridColumns: Int = 3
    
    // Unified sheet management
    @State private var activeSheet: GalleryActiveSheet?
    
    init(videoToPlay: Binding<UUID?> = .constant(nil)) {
        self._videoToPlay = videoToPlay
    }
    
    var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: viewModel.gridColumns)
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
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
                .onAppear {
                    currentGridColumns = viewModel.gridColumns
                }
                
                // Bottom action bar for selection mode
                if viewModel.isSelectionMode && viewModel.hasSelection {
                    selectionActionBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(), value: viewModel.isSelectionMode)
                }
            }
            .navigationTitle(viewModel.isSelectionMode ? String(format: "gallery.items_selected".localized, viewModel.selectionCount) : "gallery.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.isSelectionMode {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("common.cancel".localized) {
                            viewModel.exitSelectionMode()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(viewModel.hasSelection ? "gallery.deselect_all".localized : "gallery.select_all".localized) {
                            if viewModel.hasSelection {
                                viewModel.clearSelection()
                            } else {
                                if viewModel.selectedSection == .photos {
                                    viewModel.selectAllPhotos()
                                } else {
                                    viewModel.selectAllVideos()
                                }
                            }
                        }
                    }
                }
            }
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
            .alert(String(format: "gallery.delete_items_count".localized, viewModel.selectionCount), isPresented: $showingBulkDeleteAlert) {
                Button("common.delete".localized, role: .destructive) {
                    bulkDelete()
                }
                Button("common.cancel".localized, role: .cancel) { }
            } message: {
                Text("gallery.action_cannot_be_undone".localized)
            }
            .overlay(alignment: .top) {
                if showingSaveSuccess {
                    SaveSuccessToast(message: saveSuccessMessage, isShowing: $showingSaveSuccess)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(), value: showingSaveSuccess)
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
    
    // MARK: - Private Methods
    
    private func checkForVideoToPlay() {
        if let videoId = videoToPlay {
            if let video = viewModel.videos.first(where: { $0.id == videoId }) {
                viewModel.selectedSection = .videos
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    selectedVideo = video
                    videoToPlay = nil
                }
            }
        }
    }
    
    private func deleteSelectedItem() {
        if let photo = itemToDelete as? Photo {
            viewModel.deletePhoto(photo)
        } else if let video = itemToDelete as? Video {
            viewModel.deleteVideo(video)
        }
        itemToDelete = nil
    }
    
    private func bulkDelete() {
        if viewModel.selectedSection == .photos {
            viewModel.bulkDeletePhotos()
        } else {
            viewModel.bulkDeleteVideos()
        }
    }
    
    private func handlePhotoShare(_ image: UIImage, withFaceBlur: Bool) {
        GalleryActionService.shared.handlePhotoShare(image, withFaceBlur: withFaceBlur, activeSheet: $activeSheet)
    }
}

// MARK: - View Components

extension GalleryView {
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
        VStack(spacing: 0) {
            if !viewModel.photos.isEmpty {
                filterChips
            }
            
            ScrollView {
                if viewModel.photos.isEmpty {
                    emptyStateView(message: "gallery.no_photos".localized, icon: "photo")
                } else if viewModel.filteredPhotos.isEmpty {
                    emptyStateView(message: "gallery.no_photos_matching_filter".localized, icon: "photo.on.rectangle.angled")
                } else {
                    let groupedPhotos = viewModel.photosGroupedByMonth()
                    LazyVStack(pinnedViews: .sectionHeaders) {
                        ForEach(Array(groupedPhotos.enumerated()), id: \.offset) { group in
                            let index = group.offset
                            let month = group.element.0
                            let photos = group.element.1
                            Section(header: sectionHeader(title: month)) {
                                LazyVGrid(columns: columns, spacing: 2) {
                                    ForEach(photos) { photo in
                                        PhotoGridItem(
                                            photo: photo,
                                            isSelected: viewModel.selectedPhotoIds.contains(photo.id.uuidString),
                                            isSelectionMode: viewModel.isSelectionMode,
                                            onTap: {
                                                if viewModel.isSelectionMode {
                                                    viewModel.togglePhotoSelection(photo.id.uuidString)
                                                } else {
                                                    selectedPhoto = photo
                                                }
                                            },
                                            onDelete: {
                                                itemToDelete = photo
                                                showingDeleteAlert = true
                                            },
                                            onSave: {
                                                savePhoto(photo)
                                            },
                                            onShare: {
                                                sharePhoto(photo)
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 2)
                                
                                if index < groupedPhotos.count - 1 {
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
        .refreshable {
            viewModel.loadPhotos()
        }
        .sheet(isPresented: $viewModel.showingFilterOptions) {
            FilterOptionsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingDatePicker) {
            DatePickerView(viewModel: viewModel)
        }
    }
    
    private var videosSection: some View {
        ScrollView {
            if viewModel.videos.isEmpty {
                emptyStateView(message: "gallery.no_videos".localized, icon: "video")
            } else {
                let groupedVideos = viewModel.videosGroupedByMonth()
                LazyVStack(pinnedViews: .sectionHeaders) {
                    ForEach(Array(groupedVideos.enumerated()), id: \.offset) { group in
                        let index = group.offset
                        let month = group.element.0
                        let videos = group.element.1
                        Section(header: sectionHeader(title: month)) {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(videos) { video in
                                    VideoGridItem(
                                        video: video,
                                        isSelected: viewModel.selectedVideoIds.contains(video.id.uuidString),
                                        isSelectionMode: viewModel.isSelectionMode,
                                        onTap: {
                                            if viewModel.isSelectionMode {
                                                viewModel.toggleVideoSelection(video.id.uuidString)
                                            } else {
                                                selectedVideo = video
                                            }
                                        },
                                        onDelete: {
                                            itemToDelete = video
                                            showingDeleteAlert = true
                                        },
                                        onSave: {
                                            saveVideo(video)
                                        },
                                        onShare: {
                                            shareVideo(video)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 2)
                            
                            if index < groupedVideos.count - 1 {
                                Divider()
                                    .background(Color.bodyLapseLightGray)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                }
            }
        }
        .refreshable {
            viewModel.loadVideos()
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
    
    private var filterChips: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Sort toggle
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    viewModel.sortOrder = viewModel.sortOrder == .newest ? .oldest : .newest
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.sortOrder == .newest ? "arrow.down" : "arrow.up")
                            .font(.system(size: 12))
                        Text(viewModel.sortOrder == .newest ? "gallery.newest".localized : "gallery.oldest".localized)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 1)
                    )
                }
                
                // Date picker button
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    viewModel.showingDatePicker = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        if !viewModel.selectedDates.isEmpty {
                            Text("\(viewModel.selectedDates.count)")
                                .font(.caption)
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(viewModel.selectedDates.isEmpty ? .primary : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        viewModel.selectedDates.isEmpty ? Color(UIColor.tertiarySystemBackground) : Color.bodyLapseTurquoise
                    )
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(viewModel.selectedDates.isEmpty ? Color(UIColor.separator).opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
                
                Spacer()
                
                // Clear filters button
                if !viewModel.isSelectionMode && (!viewModel.selectedCategories.isEmpty || viewModel.sortOrder != .newest || !viewModel.selectedDates.isEmpty) {
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        viewModel.clearFilters()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.gray)
                    }
                }
                
                // Select button
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    if viewModel.isSelectionMode {
                        viewModel.exitSelectionMode()
                    } else {
                        viewModel.enterSelectionMode()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.isSelectionMode ? "xmark" : "checkmark.circle")
                            .font(.system(size: 14))
                        Text(viewModel.isSelectionMode ? "common.cancel".localized : "gallery.select".localized)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(viewModel.isSelectionMode ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        viewModel.isSelectionMode ? Color.red : Color(UIColor.tertiarySystemBackground)
                    )
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(viewModel.isSelectionMode ? Color.clear : Color(UIColor.separator).opacity(0.3), lineWidth: 1)
                    )
                }
            }
            
            // Category chips for premium users
            if !viewModel.isSelectionMode && viewModel.availableCategories.count > 1 && SubscriptionManagerService.shared.isPremium {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryChip(
                            title: "gallery.all".localized,
                            isSelected: viewModel.selectedCategories.isEmpty,
                            action: {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                viewModel.selectedCategories.removeAll()
                            }
                        )
                        
                        ForEach(viewModel.availableCategories) { category in
                            CategoryChip(
                                title: category.name,
                                isSelected: viewModel.selectedCategories.contains(category.id),
                                action: {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                    viewModel.toggleCategory(category.id)
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    private var selectionActionBar: some View {
        HStack(spacing: 0) {
            // Share button
            Button(action: {
                shareSelectedItems()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                    Text("common.share".localized)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
            }
            .foregroundColor(.primary)
            
            Divider()
                .frame(height: 50)
            
            // Save button
            Button(action: {
                saveSelectedItems()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title2)
                    Text("common.save".localized)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
            }
            .foregroundColor(.primary)
            
            Divider()
                .frame(height: 50)
            
            // Delete button
            Button(action: {
                showingBulkDeleteAlert = true
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.title2)
                    Text("common.delete".localized)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
            }
            .foregroundColor(.red)
        }
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: -2)
        )
    }
}

// MARK: - Action Methods

extension GalleryView {
    private func savePhoto(_ photo: Photo) {
        GalleryActionService.shared.savePhoto(photo) { [self] success, error in
            if success {
                GalleryActionService.shared.showSaveSuccess(
                    message: "gallery.photo_saved".localized,
                    showingSaveSuccess: $showingSaveSuccess,
                    saveSuccessMessage: $saveSuccessMessage
                )
            }
        }
    }
    
    private func saveVideo(_ video: Video) {
        GalleryActionService.shared.saveVideo(video) { [self] success, error in
            if success {
                GalleryActionService.shared.showSaveSuccess(
                    message: "gallery.video_saved".localized,
                    showingSaveSuccess: $showingSaveSuccess,
                    saveSuccessMessage: $saveSuccessMessage
                )
            }
        }
    }
    
    private func sharePhoto(_ photo: Photo) {
        GalleryActionService.shared.sharePhoto(photo, activeSheet: $activeSheet)
    }
    
    private func shareVideo(_ video: Video) {
        GalleryActionService.shared.shareVideo(video, activeSheet: $activeSheet)
    }
    
    private func shareSelectedItems() {
        if viewModel.selectedSection == .photos {
            let images = GalleryActionService.shared.getSelectedPhotosForSharing(from: viewModel)
            if !images.isEmpty {
                activeSheet = .share(images)
            }
        } else {
            let urls = GalleryActionService.shared.getSelectedVideosForSharing(from: viewModel)
            if !urls.isEmpty {
                activeSheet = .share(urls)
            }
        }
    }
    
    private func saveSelectedItems() {
        if viewModel.selectedSection == .photos {
            GalleryActionService.shared.bulkSavePhotosToLibrary(from: viewModel) { [self] success, error in
                if success {
                    GalleryActionService.shared.showSaveSuccess(
                        message: String(format: "gallery.photos_saved_count".localized, viewModel.selectedPhotoIds.count),
                        showingSaveSuccess: $showingSaveSuccess,
                        saveSuccessMessage: $saveSuccessMessage
                    )
                }
            }
        } else {
            GalleryActionService.shared.bulkSaveVideosToLibrary(from: viewModel) { [self] success, error in
                if success {
                    GalleryActionService.shared.showSaveSuccess(
                        message: String(format: "gallery.videos_saved_count".localized, viewModel.selectedVideoIds.count),
                        showingSaveSuccess: $showingSaveSuccess,
                        saveSuccessMessage: $saveSuccessMessage
                    )
                }
            }
        }
    }
}
