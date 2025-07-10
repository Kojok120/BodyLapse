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
    @State private var showingBulkDeleteAlert = false
    @State private var currentGridColumns: Int = 3
    
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
            // Checking for video to play
            // Find the video and play it
            if let video = viewModel.videos.first(where: { $0.id == videoId }) {
                // Found video to play
                viewModel.selectedSection = .videos
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    selectedVideo = video
                    videoToPlay = nil // Clear after playing
                }
            } else {
                // Video not found in list
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
        VStack(spacing: 0) {
            // Filter toolbar
            if !viewModel.photos.isEmpty {
                filterToolbar
                filterChips
            }
            
            ScrollView {
                if viewModel.photos.isEmpty {
                    emptyStateView(message: "gallery.no_photos".localized, icon: "photo")
                } else if viewModel.filteredPhotos.isEmpty {
                    emptyStateView(message: "gallery.no_photos_matching_filter".localized, icon: "photo.on.rectangle.angled")
                } else {
                    LazyVStack(pinnedViews: .sectionHeaders) {
                        ForEach(viewModel.photosGroupedByMonth(), id: \.0) { month, photos in
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
                LazyVStack(pinnedViews: .sectionHeaders) {
                    ForEach(viewModel.videosGroupedByMonth(), id: \.0) { month, videos in
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
                // Failed to save photo
            }
        }
    }
    
    private func saveVideo(_ video: Video) {
        viewModel.saveVideoToLibrary(video) { success, error in
            if success {
                showSaveSuccess(message: "gallery.video_saved".localized)
            } else {
                // Failed to save video
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
    
    private var filterChips: some View {
        VStack(spacing: 12) {
            // Top row: Sort toggle, Date picker, and Select button
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
            
            // Category chips for premium users (only show when not in selection mode)
            if !viewModel.isSelectionMode && viewModel.availableCategories.count > 1 && SubscriptionManagerService.shared.isPremium {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // "All" chip
                        CategoryChip(
                            title: "gallery.all".localized,
                            isSelected: viewModel.selectedCategories.isEmpty,
                            action: {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                viewModel.selectedCategories.removeAll()
                            }
                        )
                        
                        // Category chips
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
    
    private var filterToolbar: some View {
        EmptyView()
    }
    
    private func getActiveFilterCount() -> Int {
        var count = 0
        if !viewModel.selectedCategories.isEmpty {
            count += 1
        }
        if viewModel.sortOrder != .newest {
            count += 1
        }
        return count
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
    
    private func shareSelectedItems() {
        if viewModel.selectedSection == .photos {
            let images = viewModel.getSelectedPhotosForSharing()
            if !images.isEmpty {
                itemToShare = images
                showingShareSheet = true
            }
        } else {
            let urls = viewModel.getSelectedVideosForSharing()
            if !urls.isEmpty {
                itemToShare = urls
                showingShareSheet = true
            }
        }
    }
    
    private func saveSelectedItems() {
        if viewModel.selectedSection == .photos {
            viewModel.bulkSavePhotosToLibrary { success, error in
                if success {
                    showSaveSuccess(message: String(format: "gallery.photos_saved_count".localized, viewModel.selectedPhotoIds.count))
                }
            }
        } else {
            viewModel.bulkSaveVideosToLibrary { success, error in
                if success {
                    showSaveSuccess(message: String(format: "gallery.videos_saved_count".localized, viewModel.selectedVideoIds.count))
                }
            }
        }
    }
    
    private func bulkDelete() {
        if viewModel.selectedSection == .photos {
            viewModel.bulkDeletePhotos()
        } else {
            viewModel.bulkDeleteVideos()
        }
    }
}

struct FilterOptionsView: View {
    @ObservedObject var viewModel: GalleryViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("gallery.filter.category".localized) {
                    if viewModel.availableCategories.count > 1 && SubscriptionManagerService.shared.isPremium {
                        ForEach(viewModel.availableCategories) { category in
                            HStack {
                                Text(category.name)
                                Spacer()
                                if viewModel.selectedCategories.contains(category.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.bodyLapseTurquoise)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.toggleCategory(category.id)
                            }
                        }
                    } else {
                        Text("gallery.filter.all_categories".localized)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("gallery.filter.sort".localized) {
                    ForEach(GalleryViewModel.SortOrder.allCases, id: \.self) { order in
                        HStack {
                            Text(order.localizedString)
                            Spacer()
                            if viewModel.sortOrder == order {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.bodyLapseTurquoise)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.sortOrder = order
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        viewModel.clearFilters()
                    }) {
                        Text("gallery.filter.reset".localized)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("gallery.filter".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PhotoGridItem: View {
    let photo: Photo
    let isSelected: Bool
    let isSelectionMode: Bool
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
                        // Date label in top-left corner
                        Text(formatDate(photo.captureDate))
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
                loadImage()
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
    
    private func loadImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedImage = PhotoStorageService.shared.loadImage(for: photo)
            DispatchQueue.main.async {
                self.image = loadedImage
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

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
                        Text(formatDate(video.createdDate))
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

struct PhotoDetailSheet: View {
    let photo: Photo
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userSettings = UserSettingsManager.shared
    @StateObject private var subscriptionManager = SubscriptionManagerService.shared
    @State private var showingShareSheet = false
    
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

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? Color.bodyLapseTurquoise : Color(UIColor.tertiarySystemBackground)
                )
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(isSelected ? Color.clear : Color(UIColor.separator).opacity(0.5), lineWidth: 1)
                )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(minWidth: 60)
                .background(
                    isSelected ? Color.bodyLapseTurquoise : Color(UIColor.tertiarySystemBackground)
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Color(UIColor.separator).opacity(0.3), lineWidth: 1)
                )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct DatePickerView: View {
    @ObservedObject var viewModel: GalleryViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedMonth = Date()
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Month/Year selector
                monthYearSelector
                    .padding(.horizontal)
                    .padding(.top, 20)
                
                // Date chips grid
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 12)], spacing: 12) {
                        ForEach(datesInSelectedMonth(), id: \.self) { date in
                            DateChip(
                                date: date,
                                isSelected: viewModel.selectedDates.contains(where: { calendar.isDate($0, inSameDayAs: date) }),
                                hasPhotos: hasPhotosOnDate(date),
                                action: {
                                    viewModel.toggleDate(date)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("gallery.select_dates".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("gallery.clear_all".localized) {
                        viewModel.selectedDates.removeAll()
                    }
                    .disabled(viewModel.selectedDates.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var monthYearSelector: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundColor(.bodyLapseTurquoise)
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text(monthString)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(yearString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: nextMonth) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.bodyLapseTurquoise)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
    
    private func previousMonth() {
        selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
    }
    
    private func nextMonth() {
        selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
    }
    
    private var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: selectedMonth)
    }
    
    private var yearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: selectedMonth)
    }
    
    private func datesInSelectedMonth() -> [Date] {
        let startOfMonth = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? Date()
        let range = calendar.range(of: .day, in: .month, for: startOfMonth) ?? 1..<2
        
        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }
    
    private func hasPhotosOnDate(_ date: Date) -> Bool {
        return viewModel.photos.contains { photo in
            calendar.isDate(photo.captureDate, inSameDayAs: date)
        }
    }
}

struct DateChip: View {
    let date: Date
    let isSelected: Bool
    let hasPhotos: Bool
    let action: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                if hasPhotos {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.9) : Color.orange)
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 60, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.bodyLapseTurquoise : (hasPhotos ? Color(UIColor.tertiarySystemBackground) : Color(UIColor.systemGray5)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(calendar.isDateInToday(date) ? Color.bodyLapseTurquoise : Color.clear, lineWidth: 2)
            )
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .opacity(hasPhotos ? 1.0 : 0.6)
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
