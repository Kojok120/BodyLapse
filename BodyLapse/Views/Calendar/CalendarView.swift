import SwiftUI
import AVFoundation
import Photos
import PhotosUI

struct CalendarView: View {
    @StateObject var viewModel = CalendarViewModel()
    @StateObject var userSettings = UserSettingsManager.shared
    @StateObject var subscriptionManager = SubscriptionManagerService.shared
    @StateObject var weightViewModel = WeightTrackingViewModel()
    
    // MARK: - Core State
    @State var selectedDate = Date()
    @State var selectedPeriod = TimePeriod.week
    @State var selectedIndex: Int = 0
    @State var selectedChartDate: Date? = nil
    @State var currentPhoto: Photo?
    @State var currentMemo: String = ""
    @State var currentCategoryIndex: Int = 0
    @State var photosForSelectedDate: [Photo] = []
    @State var categoriesForSelectedDate: [PhotoCategory] = []
    
    // MARK: - Sheet States
    @State var showingPeriodPicker = false
    @State var showingDatePicker = false
    @State var showingWeightInput = false
    @State var showingMemoEditor = false
    @State var showingVideoGeneration = false
    @State var showingAddCategory = false
    
    // MARK: - Video Generation States  
    @State var isGeneratingVideo = false
    @State var videoGenerationProgress: Float = 0
    @State var showingVideoAlert = false
    @State var videoAlertMessage = ""
    
    // MARK: - Guidance States
    @State var showingVideoGuidance = false
    @State var showingCategoryGuidance = false
    
    // MARK: - UI States
    @State var showingSaveSuccess = false
    @State var saveSuccessMessage = ""
    @State var newCategoryToSetup: PhotoCategory?
    @State var activeSheet: ActiveSheet?
    @State var itemToShare: [Any] = []
    
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
    
    var dateRange: [Date] {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
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
                
                // Guidance overlays
                CalendarGuidanceView(
                    showingVideoGuidance: $showingVideoGuidance,
                    showingCategoryGuidance: $showingCategoryGuidance,
                    showingVideoGeneration: $showingVideoGeneration,
                    showingAddCategory: $showingAddCategory
                )
            }
        }
    }
    
    private var mainContent: some View {
        let spacing = calculateSpacing()
        return VStack(spacing: spacing) {
            CalendarHeaderView(
                isPremium: false, // No longer used, keeping for backward compatibility
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
                isPremium: true, // All users now have premium features
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
            
            // Weight tracking now available for all users
            DataGraphSection(
                selectedPeriod: selectedPeriod,
                weightViewModel: weightViewModel,
                dateRange: dateRange,
                selectedChartDate: $selectedChartDate,
                onEditWeight: {
                    showingWeightInput = true
                }
            )
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
            updateCurrentPhoto()
        }
        .onChange(of: selectedDate) { _, newDate in
            updateCurrentPhoto()
            selectedChartDate = newDate
        }
        .onChange(of: selectedChartDate) { _, newDate in
            handleChartDateChange(newDate)
        }
        .onChange(of: viewModel.dailyNotes) { _, _ in
            currentMemo = viewModel.note(for: selectedDate)?.content ?? ""
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
            CalendarDatePickerSheet(
                selectedDate: $selectedDate,
                selectedChartDate: $selectedChartDate,
                selectedIndex: $selectedIndex,
                showingDatePicker: $showingDatePicker,
                dateRange: dateRange,
                photoDates: getPhotoDates(),
                dataDates: getDataDates(), // All users can see data dates
                isPremium: true, // All users now have premium features
                onDateSelected: updateCurrentPhoto
            )
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
        .alert("calendar.video_generation".localized, isPresented: $showingVideoAlert) {
            Button("common.ok".localized) { }
        } message: {
            Text(videoAlertMessage)
        }
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
        .overlay(
            Group {
                if isGeneratingVideo {
                    VideoGenerationProgressView(progress: videoGenerationProgress)
                }
            }
        )
        .overlay(
            Group {
                if showingSaveSuccess {
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
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            },
            alignment: .top
        )
    }
}

// MARK: - Helper Methods
extension CalendarView {
    
    private func calculateSpacing() -> CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        let isSmallScreen = screenHeight < 700
        return isSmallScreen ? 4 : 6
    }
    
    private func handleOnAppear() {
        viewModel.loadPhotos()
        viewModel.loadDailyNotes()
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
    
    func updateCurrentPhoto() {
        photosForSelectedDate = viewModel.allPhotosForDate(selectedDate)
        
        // Categories now available for all users
        if viewModel.availableCategories.count > 1 {
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
        
        // Weight data now available for all users
        weightViewModel.loadEntries()
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
}
