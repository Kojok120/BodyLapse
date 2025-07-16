import SwiftUI
import AVFoundation
import Photos
import PhotosUI

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @StateObject private var userSettings = UserSettingsManager.shared
    @StateObject private var subscriptionManager = SubscriptionManagerService.shared
    @StateObject private var weightViewModel = WeightTrackingViewModel()
    @State private var selectedDate = Date()
    @State private var showingPeriodPicker = false
    @State private var showingDatePicker = false
    @State private var selectedPeriod = TimePeriod.week
    @State private var showingWeightInput = false
    @State private var currentPhoto: Photo?
    @State private var selectedIndex: Int = 0
    @State private var showingVideoGeneration = false
    @State private var isGeneratingVideo = false
    @State private var videoGenerationProgress: Float = 0
    @State private var showingVideoAlert = false
    @State private var videoAlertMessage = ""
    @State private var selectedChartDate: Date? = nil
    @State private var showingMemoEditor = false
    @State private var currentMemo: String = ""
    @State private var currentCategoryIndex: Int = 0
    @State private var photosForSelectedDate: [Photo] = []
    @State private var categoriesForSelectedDate: [PhotoCategory] = []
    @State private var showingSaveSuccess = false
    @State private var saveSuccessMessage = ""
    @State private var showingAddCategory = false
    @State private var newCategoryToSetup: PhotoCategory?
    
    // 統一的なシート管理
    @State private var activeSheet: ActiveSheet?
    @State private var itemToShare: [Any] = []
    
    enum ActiveSheet: Identifiable {
        case shareOptions(Photo)
        case share([Any])
        
        var id: String {
            switch self {
            case .shareOptions: return "shareOptions"
            case .share: return "share"
            }
        }
    }
    
    // Guidance system state
    @StateObject private var tooltipManager = TooltipManager.shared
    @State private var showingVideoGuidance = false
    @State private var showingCategoryGuidance = false
    
    var dateRange: [Date] {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
        
        // Calculate start date to ensure exactly selectedPeriod.days worth of dates
        // For 7 days: we want 7 dates including today, so start from 6 days ago
        let startDate = calendar.date(byAdding: .day, value: -(selectedPeriod.days - 1), to: endDate) ?? endDate
        
        var dates: [Date] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return dates
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                mainContent
                
                // Video guidance overlay
                if showingVideoGuidance {
                    videoGuidanceOverlay
                }
                
                // Category guidance overlay
                if showingCategoryGuidance {
                    categoryGuidanceOverlay
                }
            }
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: calculateSpacing()) {
            CalendarHeaderView(
                isPremium: subscriptionManager.isPremium,
                availableCategories: viewModel.availableCategories,
                selectedCategory: viewModel.selectedCategory,
                selectedPeriod: $selectedPeriod,
                showingPeriodPicker: $showingPeriodPicker,
                showingDatePicker: $showingDatePicker,
                showingVideoGeneration: $showingVideoGeneration,
                showingAddCategory: $showingAddCategory,
                isGeneratingVideo: isGeneratingVideo,
                onCategorySelect: { category in
                    viewModel.selectCategory(category)
                    updateCurrentPhoto()
                },
                onVideoGuidanceRequested: {
                    showingVideoGuidance = true
                },
                onCategoryGuidanceRequested: {
                    showingCategoryGuidance = true
                }
            )
            
            PhotoPreviewSection(
                selectedDate: selectedDate,
                isPremium: subscriptionManager.isPremium,
                currentPhoto: $currentPhoto,
                currentMemo: $currentMemo,
                showingMemoEditor: $showingMemoEditor,
                currentCategoryIndex: $currentCategoryIndex,
                photosForSelectedDate: photosForSelectedDate,
                categoriesForSelectedDate: categoriesForSelectedDate,
                viewModel: viewModel,
                onCategorySwitch: switchToCategory,
                onPhotoDelete: deletePhoto,
                onPhotoShare: sharePhoto,
                onPhotoCopy: copyPhoto,
                onPhotoSave: savePhoto,
                onPhotoImport: { categoryId, photoItems in
                    handlePhotoImport(categoryId: categoryId, photoItems: photoItems)
                }
            )
            
            if subscriptionManager.isPremium {
                DataGraphSection(
                    selectedPeriod: selectedPeriod,
                    weightViewModel: weightViewModel,
                    dateRange: dateRange,
                    selectedChartDate: $selectedChartDate,
                    onEditWeight: {
                        showingWeightInput = true
                    }
                )
            } else {
                ProgressBarSection(
                    dateRange: dateRange,
                    viewModel: viewModel,
                    selectedIndex: $selectedIndex,
                    selectedDate: $selectedDate,
                    selectedChartDate: $selectedChartDate
                )
            }
        }
        .withBannerAd()
        .navigationTitle("calendar.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: handleOnAppear)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToCalendarToday")), perform: handleNavigateToToday)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PhotosUpdated"))) { _ in
            viewModel.loadPhotos()
            viewModel.loadCategories()
            updateCurrentPhoto()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("WeightDataSyncComplete"))) { _ in
            // Refresh data after weight sync is complete
            updateCurrentPhoto()
        }
        .onChange(of: selectedDate) { _, newDate in
            updateCurrentPhoto()
            selectedChartDate = newDate
        }
        .onChange(of: selectedChartDate) { _, newDate in
            handleChartDateChange(newDate)
        }
        .sheet(isPresented: $showingWeightInput) {
            WeightInputView(photo: $currentPhoto, selectedDate: selectedDate, onSave: { weight, bodyFat in
                handleWeightSave(weight: weight, bodyFat: bodyFat)
            })
        }
        .sheet(isPresented: $showingVideoGeneration) {
            VideoGenerationView(
                period: selectedPeriod,
                dateRange: dateRange,
                isGenerating: $isGeneratingVideo,
                userSettings: userSettings,
                onGenerate: { options, startDate, endDate in
                    generateVideo(with: options, startDate: startDate, endDate: endDate)
                }
            )
            .onAppear {
                if !subscriptionManager.isPremium {
                    AdMobService.shared.checkAdStatus()
                    AdMobService.shared.loadInterstitialAd()
                }
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            datePickerSheet
        }
        .sheet(isPresented: $showingMemoEditor) {
            MemoEditorView(
                date: selectedDate,
                initialContent: currentMemo,
                onSave: { content in
                    viewModel.saveNote(content: content, for: selectedDate)
                    currentMemo = content
                },
                onDelete: {
                    viewModel.deleteNote(for: selectedDate)
                    currentMemo = ""
                }
            )
        }
        .alert("calendar.video_generation".localized, isPresented: $showingVideoAlert) {
            Button("common.ok".localized) { }
        } message: {
            Text(videoAlertMessage)
        }
        .overlay(
            Group {
                if isGeneratingVideo {
                    VideoGenerationProgressView(progress: videoGenerationProgress)
                }
            }
        )
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
                ShareSheet(activityItems: items)
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategorySheet { newCategory in
                if CategoryStorageService.shared.addCategory(newCategory) {
                    newCategoryToSetup = newCategory
                }
            }
        }
        .fullScreenCover(item: $newCategoryToSetup) { category in
            CategoryGuidelineSetupView(category: category)
                .onDisappear {
                    viewModel.loadCategories()
                    viewModel.selectCategory(category)
                    updateCurrentPhoto()
                }
        }
        .overlay(
            Group {
                if showingSaveSuccess {
                    saveSuccessToast
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            },
            alignment: .top
        )
        .actionSheet(isPresented: $showingPeriodPicker) {
            ActionSheet(
                title: Text("calendar.select_time_period".localized),
                buttons: TimePeriod.allCases.map { period in
                    .default(Text(period.localizedString)) {
                        selectedPeriod = period
                        selectedIndex = dateRange.count - 1
                        selectedDate = dateRange[selectedIndex]
                        selectedChartDate = dateRange[selectedIndex]
                    }
                } + [.cancel()]
            )
        }
    }
    
    private var datePickerSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("calendar.select_date".localized)
                    .font(.headline)
                    .padding(.top, 20)
                
                // Legend
                VStack(spacing: 8) {
                    HStack(spacing: 20) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(red: 0, green: 0.7, blue: 0.8))
                                .frame(width: 8, height: 8)
                            Text("calendar.has_photo".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if subscriptionManager.isPremium {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.bodyLapseYellow)
                                    .frame(width: 8, height: 8)
                                Text("calendar.data_available".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Text("calendar.data_includes_note".localized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding(.horizontal)
                
                CustomDatePicker(
                    selection: Binding(
                        get: { selectedDate },
                        set: { newDate in
                            selectedDate = newDate
                            selectedChartDate = newDate
                            
                            if let index = dateRange.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: newDate) }) {
                                selectedIndex = index
                            }
                            
                            updateCurrentPhoto()
                            showingDatePicker = false
                        }
                    ),
                    dateRange: (dateRange.first ?? Date())...(dateRange.last ?? Date()),
                    photoDates: getPhotoDates(),
                    dataDates: subscriptionManager.isPremium ? getDataDates() : Set<Date>()
                )
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("calendar.select_date".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        showingDatePicker = false
                    }
                }
            }
        }
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
    
    // MARK: - Helper Methods
    
    private func calculateSpacing() -> CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        let isSmallScreen = screenHeight < 700
        return isSmallScreen ? 4 : 6
    }
    
    private func handleOnAppear() {
        viewModel.loadPhotos()
        weightViewModel.loadEntries()
        
        selectedIndex = dateRange.count - 1
        if !dateRange.isEmpty {
            selectedDate = dateRange[selectedIndex]
        }
        
        updateCurrentPhoto()
        
        if selectedChartDate == nil {
            selectedChartDate = selectedDate
        }
    }
    
    private func handleNavigateToToday(_ notification: Notification) {
        let today = Date()
        selectedDate = today
        selectedChartDate = today
        
        if let index = dateRange.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: today) }) {
            selectedIndex = index
        }
        
        PhotoStorageService.shared.reloadPhotosFromDisk()
        viewModel.loadPhotos()
        viewModel.loadCategories()
        updateCurrentPhoto()
    }
    
    private func handleChartDateChange(_ newDate: Date?) {
        if let date = newDate {
            selectedDate = date
            updateCurrentPhoto()
            
            if let index = dateRange.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: date) }) {
                selectedIndex = index
            }
        }
    }
    
    private func updateCurrentPhoto() {
        photosForSelectedDate = viewModel.allPhotosForDate(selectedDate)
        
        if subscriptionManager.isPremium && viewModel.availableCategories.count > 1 {
            categoriesForSelectedDate = viewModel.availableCategories
            
            if let index = categoriesForSelectedDate.firstIndex(where: { $0.id == viewModel.selectedCategory.id }) {
                currentCategoryIndex = index
                currentPhoto = photosForSelectedDate.first { $0.categoryId == viewModel.selectedCategory.id }
            } else {
                currentCategoryIndex = 0
                if !categoriesForSelectedDate.isEmpty {
                    let firstCategory = categoriesForSelectedDate[0]
                    viewModel.selectCategory(firstCategory)
                    currentPhoto = photosForSelectedDate.first { $0.categoryId == firstCategory.id }
                }
            }
        } else {
            if !photosForSelectedDate.isEmpty {
                categoriesForSelectedDate = [viewModel.selectedCategory]
                currentCategoryIndex = 0
                currentPhoto = photosForSelectedDate.first { $0.categoryId == viewModel.selectedCategory.id }
            } else {
                categoriesForSelectedDate = []
                currentPhoto = nil
            }
        }
        
        currentMemo = viewModel.note(for: selectedDate)?.content ?? ""
    }
    
    private func switchToCategory(at index: Int) {
        guard index >= 0 && index < categoriesForSelectedDate.count else { return }
        
        let category = categoriesForSelectedDate[index]
        viewModel.selectCategory(category)
        currentPhoto = photosForSelectedDate.first { $0.categoryId == category.id }
        
        if subscriptionManager.isPremium {
            weightViewModel.loadEntries()
        }
    }
    
    private func handleWeightSave(weight: Double?, bodyFat: Double?) {
        if let photo = currentPhoto {
            PhotoStorageService.shared.updatePhotoMetadata(photo, weight: weight, bodyFatPercentage: bodyFat)
            viewModel.loadPhotos()
            updateCurrentPhoto()
            
            let saveDate = photo.captureDate
            let entry = WeightEntry(
                date: saveDate,
                weight: weight ?? 0,
                bodyFatPercentage: bodyFat,
                linkedPhotoID: photo.id.uuidString
            )
            
            Task {
                do {
                    if weight != nil || bodyFat != nil {
                        try await WeightStorageService.shared.saveEntry(entry)
                    } else {
                        if let existingEntry = try await WeightStorageService.shared.getEntry(for: saveDate) {
                            try await WeightStorageService.shared.deleteEntry(existingEntry)
                        }
                    }
                    
                    await MainActor.run {
                        weightViewModel.loadEntries()
                    }
                } catch {
                    print("[CalendarView] Error saving/deleting weight entry: \(error)")
                }
            }
        } else {
            let saveDate = selectedDate
            let entry = WeightEntry(
                date: saveDate,
                weight: weight ?? 0,
                bodyFatPercentage: bodyFat,
                linkedPhotoID: nil
            )
            
            Task {
                do {
                    if weight != nil || bodyFat != nil {
                        try await WeightStorageService.shared.saveEntry(entry)
                    }
                    
                    await MainActor.run {
                        weightViewModel.loadEntries()
                    }
                } catch {
                    print("[CalendarView] Error saving weight entry: \(error)")
                }
            }
        }
    }
    
    private func generateVideo(with options: VideoGenerationService.VideoGenerationOptions, startDate: Date, endDate: Date) {
        isGeneratingVideo = true
        videoGenerationProgress = 0
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        let dateRange = startOfDay...endOfDay
        
        VideoGenerationService.shared.generateVideo(
            from: viewModel.photos,
            in: dateRange,
            options: options,
            progress: { progress in
                DispatchQueue.main.async {
                    self.videoGenerationProgress = progress
                }
            },
            completion: { result in
                DispatchQueue.main.async {
                    self.isGeneratingVideo = false
                    self.videoGenerationProgress = 0
                    
                    switch result {
                    case .success(let video):
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NavigateToGalleryAndPlayVideo"),
                            object: nil,
                            userInfo: ["videoId": video.id]
                        )
                    case .failure(let error):
                        self.videoAlertMessage = error.localizedDescription
                        self.showingVideoAlert = true
                    }
                }
            }
        )
    }
    
    private func deletePhoto(_ photo: Photo) {
        do {
            try PhotoStorageService.shared.deletePhoto(photo)
            viewModel.loadPhotos()
            viewModel.loadCategories()
            updateCurrentPhoto()
            
            if photo.weight != nil || photo.bodyFatPercentage != nil {
                Task {
                    let remainingPhotosForDate = PhotoStorageService.shared.getPhotosForDate(photo.captureDate)
                    
                    if remainingPhotosForDate.isEmpty {
                        if let existingEntry = try await WeightStorageService.shared.getEntry(for: photo.captureDate) {
                            try await WeightStorageService.shared.deleteEntry(existingEntry)
                        }
                    }
                    
                    await MainActor.run {
                        weightViewModel.loadEntries()
                    }
                }
            }
            
            NotificationCenter.default.post(name: Notification.Name("PhotosUpdated"), object: nil)
        } catch {
            videoAlertMessage = "Failed to delete photo: \(error.localizedDescription)"
            showingVideoAlert = true
        }
    }
    
    private func copyPhoto(_ photo: Photo) {
        guard let image = PhotoStorageService.shared.loadImage(for: photo) else { return }
        UIPasteboard.general.image = image
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func sharePhoto(_ photo: Photo) {
        activeSheet = .shareOptions(photo)
    }
    
    private func handlePhotoShare(_ image: UIImage, withFaceBlur: Bool) {
        itemToShare = [image]
        activeSheet = .share([image])
    }
    
    private func savePhoto(_ photo: Photo) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    self.videoAlertMessage = "gallery.photo_library_access_denied".localized
                    self.showingVideoAlert = true
                }
                return
            }
            
            guard let image = PhotoStorageService.shared.loadImage(for: photo) else {
                DispatchQueue.main.async {
                    self.videoAlertMessage = "Failed to load image"
                    self.showingVideoAlert = true
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.showSaveSuccess(message: "gallery.photo_saved".localized)
                    } else {
                        self.videoAlertMessage = error?.localizedDescription ?? "Failed to save photo"
                        self.showingVideoAlert = true
                    }
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
    
    private func getPhotoDates() -> Set<Date> {
        let calendar = Calendar.current
        var photoDates = Set<Date>()
        
        for photo in viewModel.photos {
            if let date = calendar.dateInterval(of: .day, for: photo.captureDate)?.start {
                photoDates.insert(date)
            }
        }
        
        return photoDates
    }
    
    private func getDataDates() -> Set<Date> {
        let calendar = Calendar.current
        var dataDates = Set<Date>()
        
        for entry in weightViewModel.weightEntries {
            if entry.weight > 0 || entry.bodyFatPercentage != nil {
                if let date = calendar.dateInterval(of: .day, for: entry.date)?.start {
                    dataDates.insert(date)
                }
            }
        }
        
        for note in viewModel.dailyNotes.values {
            if let date = calendar.dateInterval(of: .day, for: note.date)?.start {
                dataDates.insert(date)
            }
        }
        
        return dataDates
    }
    
    private func handlePhotoImport(categoryId: String, photoItems: [PhotosPickerItem]) {
        Task {
            do {
                guard let item = photoItems.first,
                      let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    throw NSError(domain: "PhotoImport", code: 1, userInfo: [NSLocalizedDescriptionKey: "calendar.invalid_image".localized])
                }
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dateString = dateFormatter.string(from: selectedDate)
                if PhotoStorageService.shared.photoExists(for: dateString, categoryId: categoryId) {
                    throw NSError(domain: "PhotoImport", code: 2, userInfo: [NSLocalizedDescriptionKey: "calendar.photo_already_exists".localized])
                }
                
                let photo = try PhotoStorageService.shared.savePhoto(
                    image,
                    captureDate: selectedDate,
                    categoryId: categoryId,
                    weight: nil,
                    bodyFatPercentage: nil
                )
                
                await MainActor.run {
                    viewModel.loadPhotos()
                    viewModel.loadCategories()
                    updateCurrentPhoto()
                    showSaveSuccess(message: "calendar.photo_imported".localized)
                }
            } catch {
                await MainActor.run {
                    videoAlertMessage = error.localizedDescription
                    showingVideoAlert = true
                }
            }
        }
    }
    
    // MARK: - Video Guidance Overlay
    private var videoGuidanceOverlay: some View {
        Color.black.opacity(0.1)
            .ignoresSafeArea()
            .onTapGesture {
                dismissVideoGuidance()
            }
            .overlay(
                GeometryReader { geometry in
                    VStack {
                        // Position tooltip above the button area
                        HStack {
                            Spacer()
                            videoGuidanceTooltip
                                .padding(.trailing, 25) // Align with button position
                        }
                        .padding(.top, 75) // Move closer to button
                        
                        Spacer()
                    }
                }
            )
    }
    
    private var videoGuidanceTooltip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tooltipManager.getTitle(for: .videoGeneration))
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    dismissVideoGuidance()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Text(tooltipManager.getDescription(for: .videoGeneration))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
            
            Button(action: {
                dismissVideoGuidance()
            }) {
                HStack {
                    Spacer()
                    Text("guidance.got_it".localized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.2))
                )
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .frame(maxWidth: 280)
        .scaleEffect(showingVideoGuidance ? 1.0 : 0.8)
        .opacity(showingVideoGuidance ? 1.0 : 0.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingVideoGuidance)
    }
    
    // MARK: - Category Guidance Overlay
    private var categoryGuidanceOverlay: some View {
        Color.black.opacity(0.1)
            .ignoresSafeArea()
            .onTapGesture {
                dismissCategoryGuidance()
            }
            .overlay(
                GeometryReader { geometry in
                    VStack {
                        // Position tooltip above the button area
                        HStack {
                            categoryGuidanceTooltip
                                .padding(.leading, 50) // Align with plus button position (account for "正面" button width)
                            Spacer()
                        }
                        .padding(.top, 50) // Move closer to button
                        
                        Spacer()
                    }
                }
            )
    }
    
    private var categoryGuidanceTooltip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tooltipManager.getTitle(for: .categoryAdding))
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    dismissCategoryGuidance()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Text(tooltipManager.getDescription(for: .categoryAdding))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
            
            Button(action: {
                dismissCategoryGuidance()
            }) {
                HStack {
                    Spacer()
                    Text("guidance.got_it".localized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.2))
                )
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .frame(maxWidth: 280)
        .scaleEffect(showingCategoryGuidance ? 1.0 : 0.8)
        .opacity(showingCategoryGuidance ? 1.0 : 0.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingCategoryGuidance)
    }
    
    // MARK: - Guidance Helper Methods
    private func dismissVideoGuidance() {
        showingVideoGuidance = false
        tooltipManager.markFeatureCompleted(for: .videoGeneration)
        
        // After dismissing guidance, proceed with video generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showingVideoGeneration = true
        }
    }
    
    private func dismissCategoryGuidance() {
        showingCategoryGuidance = false
        tooltipManager.markFeatureCompleted(for: .categoryAdding)
        
        // After dismissing guidance, proceed with adding category
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showingAddCategory = true
        }
    }
}