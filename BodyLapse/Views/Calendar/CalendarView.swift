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
    @State private var showingDeleteAlert = false
    @State private var photoToDelete: Photo?
    @State private var showingShareSheet = false
    @State private var itemToShare: [Any] = []
    @State private var showingSaveSuccess = false
    @State private var saveSuccessMessage = ""
    @State private var showingAddCategory = false
    @State private var newCategoryToSetup: PhotoCategory?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isImportingPhoto = false
    @State private var importCategoryId: String?
    
    enum TimePeriod: String, CaseIterable {
        case week = "7 Days"
        case month = "30 Days"
        case threeMonths = "3 Months"
        case sixMonths = "6 Months"
        case year = "1 Year"
        
        var localizedString: String {
            switch self {
            case .week: return "calendar.period.7days".localized
            case .month: return "calendar.period.30days".localized
            case .threeMonths: return "calendar.period.3months".localized
            case .sixMonths: return "calendar.period.6months".localized
            case .year: return "calendar.period.1year".localized
            }
        }
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            case .year: return 365
            }
        }
    }
    
    var dateRange: [Date] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -selectedPeriod.days + 1, to: endDate) ?? endDate
        
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
            mainContent
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: calculateSpacing()) {
            headerView
            
            photoPreviewSection
            
            if subscriptionManager.isPremium {
                dataGraphSection
            } else {
                progressBarSection
            }
        }
        .withBannerAd()
        .navigationTitle("calendar.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: handleOnAppear)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToCalendarToday")), perform: handleNavigateToToday)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PhotosUpdated"))) { _ in
            // Reload data when photos are updated
            viewModel.loadPhotos()
            viewModel.loadCategories()
            updateCurrentPhoto()
        }
        .onChange(of: selectedDate) { _, newDate in
            updateCurrentPhoto()
            selectedChartDate = newDate  // Sync chart selection when date changes
        }
        .onChange(of: selectedChartDate) { _, newDate in
            handleChartDateChange(newDate)
        }
        .sheet(isPresented: $showingWeightInput) {
            weightInputSheet
        }
        .sheet(isPresented: $showingVideoGeneration) {
            videoGenerationSheet
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
                    // Update currentMemo immediately after saving
                    currentMemo = content
                },
                onDelete: {
                    viewModel.deleteNote(for: selectedDate)
                    // Update currentMemo immediately after deletion
                    currentMemo = ""
                }
            )
        }
        .alert("calendar.video_generation".localized, isPresented: $showingVideoAlert) {
            Button("common.ok".localized) { }
        } message: {
            Text(videoAlertMessage)
        }
        .alert("calendar.confirm_delete_photo".localized, isPresented: $showingDeleteAlert) {
            Button("common.cancel".localized, role: .cancel) { }
            Button("common.delete".localized, role: .destructive) {
                if let photo = photoToDelete {
                    deletePhoto(photo)
                }
            }
        } message: {
            Text("calendar.delete_photo_message".localized)
        }
        .overlay(
            Group {
                if isGeneratingVideo {
                    VideoGenerationProgressView(progress: videoGenerationProgress)
                }
            }
        )
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: itemToShare)
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategorySheet { newCategory in
                if CategoryStorageService.shared.addCategory(newCategory) {
                    // Set the new category for guideline setup
                    newCategoryToSetup = newCategory
                } else {
                    // Handle error - category couldn't be added
                }
            }
        }
        .fullScreenCover(item: $newCategoryToSetup) { category in
            CategoryGuidelineSetupView(category: category)
                .onDisappear {
                    // Reload categories
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
    }
    
    private func handleOnAppear() {
        viewModel.loadPhotos()
        weightViewModel.loadEntries()
        
        // Initialize selectedIndex to today (rightmost position)
        selectedIndex = dateRange.count - 1
        if !dateRange.isEmpty {
            selectedDate = dateRange[selectedIndex]
        }
        
        updateCurrentPhoto()
        
        // Initialize chart date to selected date
        if selectedChartDate == nil {
            selectedChartDate = selectedDate
        }
        
        // Debug weight entries after a delay to ensure loading is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("[Calendar] Weight entries after delay: \(weightViewModel.weightEntries.count)")
            if let firstEntry = weightViewModel.weightEntries.first {
                print("[Calendar] First entry - date: \(firstEntry.date), weight: \(firstEntry.weight)")
            }
            print("[Calendar] Is premium: \(subscriptionManager.isPremium)")
        }
    }
    
    private func handleNavigateToToday(_ notification: Notification) {
        // Set selected date to today
        let today = Date()
        selectedDate = today
        selectedChartDate = today
        
        // Update index to match today's date
        if let index = dateRange.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: today) }) {
            selectedIndex = index
        }
        
        // Force reload photos from disk to ensure we have the latest
        PhotoStorageService.shared.reloadPhotosFromDisk()
        
        // Reload photos and categories in viewModel
        viewModel.loadPhotos()
        viewModel.loadCategories()
        
        // Update current photo and category information
        updateCurrentPhoto()
        
        // The updateCurrentPhoto call above should have already handled category updates correctly
    }
    
    private func handleChartDateChange(_ newDate: Date?) {
        if let date = newDate {
            // Update selected date when chart date changes
            selectedDate = date
            updateCurrentPhoto()
            
            // Update index to match selected date
            if let index = dateRange.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: date) }) {
                selectedIndex = index
            }
        }
    }
    
    private var weightInputSheet: some View {
        WeightInputView(photo: $currentPhoto, selectedDate: selectedDate, onSave: { weight, bodyFat in
            handleWeightSave(weight: weight, bodyFat: bodyFat)
        })
        .onAppear {
            // Auto-fill from HealthKit if enabled
            if subscriptionManager.isPremium && userSettings.settings.healthKitEnabled && currentPhoto?.weight == nil {
                HealthKitService.shared.fetchLatestWeight { weight, _ in
                    if let w = weight, self.currentPhoto?.weight == nil {
                        self.currentPhoto?.weight = w
                    }
                }
                HealthKitService.shared.fetchLatestBodyFatPercentage { bodyFat, _ in
                    if let bf = bodyFat, self.currentPhoto?.bodyFatPercentage == nil {
                        self.currentPhoto?.bodyFatPercentage = bf
                    }
                }
            }
        }
    }
    
    private func handleWeightSave(weight: Double?, bodyFat: Double?) {
        if let photo = currentPhoto {
            print("[CalendarView] Saving weight data - weight: \(weight ?? -1), bodyFat: \(bodyFat ?? -1)")
            
            // Update photo metadata
            PhotoStorageService.shared.updatePhotoMetadata(photo, weight: weight, bodyFatPercentage: bodyFat)
            viewModel.loadPhotos()
            updateCurrentPhoto()
            
            // Save to weight tracking - handle both saving new data and clearing existing data
            let saveDate = photo.captureDate
            let entry = WeightEntry(
                date: saveDate,
                weight: weight ?? 0, // Use 0 if weight is nil (cleared)
                bodyFatPercentage: bodyFat,
                linkedPhotoID: photo.id.uuidString
            )
            
            Task {
                do {
                    if weight != nil || bodyFat != nil {
                        // Save the entry if we have any data
                        try await WeightStorageService.shared.saveEntry(entry)
                        print("[CalendarView] Saved weight entry to WeightStorageService")
                    } else {
                        // Delete the entry if both are nil
                        if let existingEntry = try await WeightStorageService.shared.getEntry(for: saveDate) {
                            try await WeightStorageService.shared.deleteEntry(existingEntry)
                            print("[CalendarView] Deleted weight entry from WeightStorageService")
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
            // Handle case where there's no photo for the selected date
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
                        print("[CalendarView] Saved weight entry without photo")
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
    
    private var videoGenerationSheet: some View {
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
            // Pre-load interstitial ad when sheet appears
            if !subscriptionManager.isPremium {
                print("[VideoGenerationView] Sheet appeared - checking ad status")
                AdMobService.shared.checkAdStatus()
                AdMobService.shared.loadInterstitialAd()
            }
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
                                .fill(Color(red: 0, green: 0.7, blue: 0.8)) // Turquoise blue
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
                            
                            // Update index to match selected date
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
        
        // Weight and body fat entries
        for entry in weightViewModel.weightEntries {
            if entry.weight > 0 || entry.bodyFatPercentage != nil {
                if let date = calendar.dateInterval(of: .day, for: entry.date)?.start {
                    dataDates.insert(date)
                }
            }
        }
        
        // Memo entries
        for note in viewModel.dailyNotes.values {
            if let date = calendar.dateInterval(of: .day, for: note.date)?.start {
                dataDates.insert(date)
            }
        }
        
        return dataDates
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            // Category selection (Premium feature)
            if subscriptionManager.isPremium {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.availableCategories) { category in
                            Button(action: {
                                viewModel.selectCategory(category)
                                updateCurrentPhoto()
                            }) {
                                Text(category.name)
                                    .font(.system(size: 14, weight: viewModel.selectedCategory.id == category.id ? .semibold : .regular))
                                    .foregroundColor(viewModel.selectedCategory.id == category.id ? .white : .primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(viewModel.selectedCategory.id == category.id ? Color.bodyLapseTurquoise : Color(UIColor.secondarySystemBackground))
                                    )
                            }
                        }
                        
                        // Add category button
                        if CategoryStorageService.shared.canAddMoreCategories() {
                            Button(action: {
                                showingAddCategory = true
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color(UIColor.secondarySystemBackground))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            HStack {
                HStack(spacing: 8) {
                    Button(action: {
                        showingPeriodPicker = true
                    }) {
                        HStack {
                            Text(selectedPeriod.localizedString)
                                .font(.system(size: 16, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        showingDatePicker = true
                    }) {
                        Image(systemName: "calendar")
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                            .padding(8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                }
                .actionSheet(isPresented: $showingPeriodPicker) {
                    ActionSheet(
                        title: Text("calendar.select_time_period".localized),
                        buttons: TimePeriod.allCases.map { period in
                            .default(Text(period.localizedString)) {
                                selectedPeriod = period
                                selectedIndex = dateRange.count - 1
                                selectedDate = dateRange[selectedIndex]
                                selectedChartDate = dateRange[selectedIndex]  // Sync chart selection
                            }
                        } + [.cancel()]
                    )
                }
                
                Spacer()
                
                Button(action: {
                    showingVideoGeneration = true
                }) {
                    HStack {
                        Image(systemName: "video.fill")
                        Text("calendar.generate".localized)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.bodyLapseYellow)
                    .cornerRadius(20)
                }
                .disabled(isGeneratingVideo)
            }
            .padding(.horizontal)
        }
    }
    
    private var photoPreviewSection: some View {
        VStack(spacing: 8) {
            // Date display - only for free users
            if !subscriptionManager.isPremium {
                Text(formatDate(selectedDate))
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.top, 8)
            }
            
            // Memo display - always show section
            HStack {
                Image(systemName: currentMemo.isEmpty ? "note.text.badge.plus" : "note.text")
                    .font(.caption)
                    .foregroundColor(currentMemo.isEmpty ? .secondary : .bodyLapseTurquoise)
                
                if currentMemo.isEmpty {
                    Text("calendar.add_memo".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(currentMemo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
            .onTapGesture {
                showingMemoEditor = true
            }
            
            // Photo viewer with TabView for smooth swiping
            if photosForSelectedDate.isEmpty {
                // No photo placeholder
                GeometryReader { geometry in
                    VStack(spacing: 20) {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("calendar.no_photo".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        PhotosPicker(
                            selection: $selectedPhotoItems,
                            maxSelectionCount: 1,
                            matching: .images
                        ) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("calendar.upload_photo".localized)
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.bodyLapseTurquoise)
                            .cornerRadius(20)
                        }
                        .onChange(of: selectedPhotoItems) { _, items in
                            if !items.isEmpty {
                                importCategoryId = viewModel.selectedCategory.id
                                handlePhotoImport()
                            }
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .frame(height: calculatePhotoHeight())
            } else if categoriesForSelectedDate.count > 1 {
                // Multiple categories - use TabView for smooth swiping
                TabView(selection: $currentCategoryIndex) {
                    ForEach(0..<categoriesForSelectedDate.count, id: \.self) { index in
                        GeometryReader { geometry in
                            let categoryId = categoriesForSelectedDate[index].id
                            if let photo = photosForSelectedDate.first(where: { $0.categoryId == categoryId }),
                               let uiImage = PhotoStorageService.shared.loadImage(for: photo) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .tag(index)
                                    .contextMenu {
                                        Button {
                                            copyPhoto(photo)
                                        } label: {
                                            Label("common.copy".localized, systemImage: "doc.on.doc")
                                        }
                                        
                                        Button {
                                            sharePhoto(photo)
                                        } label: {
                                            Label("common.share".localized, systemImage: "square.and.arrow.up")
                                        }
                                        
                                        Button {
                                            savePhoto(photo)
                                        } label: {
                                            Label("gallery.save_to_photos".localized, systemImage: "square.and.arrow.down")
                                        }
                                        
                                        Divider()
                                        
                                        Button(role: .destructive) {
                                            photoToDelete = photo
                                            showingDeleteAlert = true
                                        } label: {
                                            Label("common.delete".localized, systemImage: "trash")
                                        }
                                    }
                            } else {
                                // Show placeholder for categories without photos
                                VStack(spacing: 20) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 60))
                                        .foregroundColor(.gray)
                                    Text("calendar.no_photo".localized)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    PhotosPicker(
                                        selection: $selectedPhotoItems,
                                        maxSelectionCount: 1,
                                        matching: .images
                                    ) {
                                        HStack {
                                            Image(systemName: "square.and.arrow.up")
                                            Text("calendar.upload_photo".localized)
                                        }
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.bodyLapseTurquoise)
                                        .cornerRadius(20)
                                    }
                                    .onChange(of: selectedPhotoItems) { _, items in
                                        if !items.isEmpty {
                                            importCategoryId = categoriesForSelectedDate[index].id
                                            handlePhotoImport()
                                        }
                                    }
                                }
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .tag(index)
                            }
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: subscriptionManager.isPremium ? UIScreen.main.bounds.height * 0.38 : UIScreen.main.bounds.height * 0.46)
                .background(Color.black)
                .cornerRadius(12)
                .onChange(of: currentCategoryIndex) { _, newIndex in
                    // Haptic feedback when page changes
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    
                    // Update the current photo
                    if newIndex < categoriesForSelectedDate.count {
                        switchToCategory(at: newIndex)
                    }
                }
            } else {
                // Single category - simple image display
                GeometryReader { geometry in
                    if let photo = currentPhoto,
                       let uiImage = PhotoStorageService.shared.loadImage(for: photo) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .contextMenu {
                                Button {
                                    copyPhoto(photo)
                                } label: {
                                    Label("common.copy".localized, systemImage: "doc.on.doc")
                                }
                                
                                Button {
                                    sharePhoto(photo)
                                } label: {
                                    Label("common.share".localized, systemImage: "square.and.arrow.up")
                                }
                                
                                Button {
                                    savePhoto(photo)
                                } label: {
                                    Label("gallery.save_to_photos".localized, systemImage: "square.and.arrow.down")
                                }
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    photoToDelete = photo
                                    showingDeleteAlert = true
                                } label: {
                                    Label("common.delete".localized, systemImage: "trash")
                                }
                            }
                    } else {
                        // Show placeholder when no photo for current category
                        VStack(spacing: 20) {
                            Image(systemName: "photo")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("calendar.no_photo".localized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            PhotosPicker(
                                selection: $selectedPhotoItems,
                                maxSelectionCount: 1,
                                matching: .images
                            ) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("calendar.upload_photo".localized)
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.bodyLapseTurquoise)
                                .cornerRadius(20)
                            }
                            .onChange(of: selectedPhotoItems) { _, items in
                                if !items.isEmpty {
                                    importCategoryId = viewModel.selectedCategory.id
                                    handlePhotoImport()
                                }
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
                .frame(height: calculatePhotoHeight())
                .background(Color.black)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }
    
    private func convertedWeight(_ weight: Double) -> Double {
        userSettings.settings.weightUnit == .kg ? weight : weight * 2.20462
    }
    
    private var progressBarSection: some View {
        VStack(spacing: 12) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(UIColor.systemGray5))
                        .frame(height: 60)
                    
                    HStack(spacing: 0) {
                        ForEach(0..<dateRange.count, id: \.self) { index in
                            let date = dateRange[index]
                            let hasPhoto = viewModel.photos.contains { photo in
                                Calendar.current.isDate(photo.captureDate, inSameDayAs: date)
                            }
                            let hasNote = viewModel.note(for: date) != nil
                            
                            Rectangle()
                                .fill(hasPhoto ? Color.accentColor : Color.clear)
                                .frame(width: geometry.size.width / CGFloat(dateRange.count))
                                .overlay(
                                    Rectangle()
                                        .stroke(Color(UIColor.systemGray4), lineWidth: 0.5)
                                )
                                .overlay(
                                    // Memo indicator dot
                                    VStack {
                                        if hasNote {
                                            Circle()
                                                .fill(Color.bodyLapseTurquoise)
                                                .frame(width: 4, height: 4)
                                                .padding(.top, 4)
                                        }
                                        Spacer()
                                    }
                                )
                        }
                    }
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 3)
                        )
                        .position(
                            x: {
                                let segmentWidth = geometry.size.width / CGFloat(dateRange.count)
                                let centerX = segmentWidth * CGFloat(selectedIndex) + (segmentWidth / 2)
                                // Constrain position to keep circle fully visible
                                return max(10, min(geometry.size.width - 10, centerX))
                            }(),
                            y: 40
                        )
                }
                .frame(height: 60)
                .padding(.vertical, 10)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let totalWidth = geometry.size.width
                            let segmentWidth = totalWidth / CGFloat(dateRange.count)
                            let newIndex = Int((value.location.x / segmentWidth).rounded())
                            
                            if newIndex >= 0 && newIndex < dateRange.count {
                                selectedIndex = newIndex
                                selectedDate = dateRange[newIndex]
                                selectedChartDate = dateRange[newIndex]  // Sync chart selection
                            }
                        }
                )
                .onTapGesture { location in
                    let totalWidth = geometry.size.width
                    let segmentWidth = totalWidth / CGFloat(dateRange.count)
                    let newIndex = Int((location.x / segmentWidth).rounded())
                    
                    if newIndex >= 0 && newIndex < dateRange.count {
                        selectedIndex = newIndex
                        selectedDate = dateRange[newIndex]
                        selectedChartDate = dateRange[newIndex]  // Sync chart selection
                    }
                }
            }
            .frame(height: 80)
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    private var dataGraphSection: some View {
        VStack(spacing: 6) {
            if #available(iOS 16.0, *) {
                let filteredEntries = weightViewModel.filteredEntries(for: getWeightTimeRange())
                let fullRange: ClosedRange<Date> = {
                    if let first = dateRange.first, let last = dateRange.last {
                        return first...last
                    } else {
                        return Date()...Date()
                    }
                }()
                
                // Always show the weight chart view for premium users
                // InteractiveWeightChartView handles empty data internally
                InteractiveWeightChartView(
                    entries: filteredEntries,
                    selectedDate: $selectedChartDate,
                    currentPhoto: currentPhoto,
                    onEditWeight: {
                        showingWeightInput = true
                    },
                    fullDateRange: fullRange
                )
                .padding(.horizontal)
                .onChange(of: selectedPeriod) { _, _ in
                    // Reset chart selection when period changes
                    selectedChartDate = nil
                }
            } else {
                Text("calendar.ios16_required".localized)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(15)
                    .padding(.horizontal)
            }
        }
    }
    
    private func getWeightTimeRange() -> WeightTimeRange {
        switch selectedPeriod {
        case .week: return .week
        case .month: return .month
        case .threeMonths: return .threeMonths
        case .sixMonths: return .threeMonths // Use 3 months as fallback
        case .year: return .year
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        // Check current language and set appropriate format
        let currentLanguage = LanguageManager.shared.currentLanguage
        switch currentLanguage {
        case "ja":
            formatter.dateFormat = "yyyy/MM/dd"
        case "ko":
            formatter.dateFormat = "yyyy.MM.dd"
        default:
            formatter.dateFormat = "MMM d, yyyy"
        }
        
        return formatter.string(from: date)
    }
    
    private func updateCurrentPhoto() {
        // Get all photos for selected date
        photosForSelectedDate = viewModel.allPhotosForDate(selectedDate)
        
        // For premium users with multiple categories, show all available categories
        if subscriptionManager.isPremium && viewModel.availableCategories.count > 1 {
            // Show all available categories regardless of whether they have photos
            categoriesForSelectedDate = viewModel.availableCategories
            
            // Find the index of the currently selected category
            if let index = categoriesForSelectedDate.firstIndex(where: { $0.id == viewModel.selectedCategory.id }) {
                currentCategoryIndex = index
                // Find photo for the current category (might be nil)
                currentPhoto = photosForSelectedDate.first { $0.categoryId == viewModel.selectedCategory.id }
            } else {
                // Fallback to first category if current selection is invalid
                currentCategoryIndex = 0
                if !categoriesForSelectedDate.isEmpty {
                    let firstCategory = categoriesForSelectedDate[0]
                    viewModel.selectCategory(firstCategory)
                    currentPhoto = photosForSelectedDate.first { $0.categoryId == firstCategory.id }
                }
            }
        } else {
            // Single category or free user
            if !photosForSelectedDate.isEmpty {
                categoriesForSelectedDate = [viewModel.selectedCategory]
                currentCategoryIndex = 0
                currentPhoto = photosForSelectedDate.first { $0.categoryId == viewModel.selectedCategory.id }
            } else {
                // No photos at all
                categoriesForSelectedDate = []
                currentPhoto = nil
            }
        }
        
        currentMemo = viewModel.note(for: selectedDate)?.content ?? ""
    }
    
    private func switchToCategory(at index: Int) {
        guard index >= 0 && index < categoriesForSelectedDate.count else { return }
        
        let category = categoriesForSelectedDate[index]
        
        // Update selected category in viewModel first
        viewModel.selectCategory(category)
        
        // Find photo for this category (might be nil if no photo exists)
        currentPhoto = photosForSelectedDate.first { $0.categoryId == category.id }
        
        // Update weight input if premium
        if subscriptionManager.isPremium {
            // Trigger weight data reload for new category
            weightViewModel.loadEntries()
        }
    }
    
    private func generateVideo(with options: VideoGenerationService.VideoGenerationOptions, startDate: Date, endDate: Date) {
        isGeneratingVideo = true
        videoGenerationProgress = 0
        
        let dateRange = startDate...endDate
        
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
                        // Navigate to Gallery and play the video
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
            
            // Reload photos
            viewModel.loadPhotos()
            viewModel.loadCategories()
            updateCurrentPhoto()
            
            // Also update weight tracking if this photo had weight data
            if photo.weight != nil || photo.bodyFatPercentage != nil {
                Task {
                    // If there's a weight entry for this date and no other photos exist for this date,
                    // we should consider deleting the weight entry
                    let remainingPhotosForDate = PhotoStorageService.shared.getPhotosForDate(photo.captureDate)
                    
                    if remainingPhotosForDate.isEmpty {
                        // No more photos for this date, delete the weight entry
                        if let existingEntry = try await WeightStorageService.shared.getEntry(for: photo.captureDate) {
                            try await WeightStorageService.shared.deleteEntry(existingEntry)
                        }
                    }
                    
                    await MainActor.run {
                        weightViewModel.loadEntries()
                    }
                }
            }
            
            // Post notification that photos have been updated
            NotificationCenter.default.post(name: Notification.Name("PhotosUpdated"), object: nil)
            
        } catch {
            print("Failed to delete photo: \(error)")
            // Optionally show error alert
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
        guard let image = PhotoStorageService.shared.loadImage(for: photo) else { return }
        itemToShare = [image]
        showingShareSheet = true
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
    
    private func calculateSpacing() -> CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        let isSmallScreen = screenHeight < 700
        return isSmallScreen ? 4 : 6
    }
    
    private func calculatePhotoHeight() -> CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        
        // Small screen detection (iPhone SE, etc.)
        let isSmallScreen = screenHeight < 700
        
        if isSmallScreen {
            // For small screens, use smaller ratios to prevent overlap
            return subscriptionManager.isPremium ? screenHeight * 0.28 : screenHeight * 0.35
        } else {
            // For normal screens, use original ratios
            return subscriptionManager.isPremium ? screenHeight * 0.38 : screenHeight * 0.46
        }
    }
    
    private func handlePhotoImport() {
        guard let item = selectedPhotoItems.first,
              let categoryId = importCategoryId else { return }
        
        isImportingPhoto = true
        
        Task {
            do {
                // Load the image data
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    throw NSError(domain: "PhotoImport", code: 1, userInfo: [NSLocalizedDescriptionKey: "calendar.invalid_image".localized])
                }
                
                // Check if photo already exists for this date and category
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dateString = dateFormatter.string(from: selectedDate)
                if PhotoStorageService.shared.photoExists(for: dateString, categoryId: categoryId) {
                    throw NSError(domain: "PhotoImport", code: 2, userInfo: [NSLocalizedDescriptionKey: "calendar.photo_already_exists".localized])
                }
                
                // Save the photo
                let photo = try PhotoStorageService.shared.savePhoto(
                    image,
                    captureDate: selectedDate,
                    categoryId: categoryId,
                    weight: nil,
                    bodyFatPercentage: nil
                )
                
                await MainActor.run {
                    // Reload photos and update view
                    viewModel.loadPhotos()
                    viewModel.loadCategories()
                    updateCurrentPhoto()
                    
                    // Clear selection
                    selectedPhotoItems = []
                    isImportingPhoto = false
                    
                    // Show success message
                    showSaveSuccess(message: "calendar.photo_imported".localized)
                }
            } catch {
                await MainActor.run {
                    isImportingPhoto = false
                    selectedPhotoItems = []
                    videoAlertMessage = error.localizedDescription
                    showingVideoAlert = true
                }
            }
        }
    }
}

struct WeightInputView: View {
    @Binding var photo: Photo?
    let selectedDate: Date
    let onSave: (Double?, Double?) -> Void
    
    @State private var weightText = ""
    @State private var bodyFatText = ""
    @StateObject private var userSettings = UserSettingsManager.shared
    @StateObject private var subscriptionManager = SubscriptionManagerService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isLoadingHealthData = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "scalemass")
                        .font(.system(size: 50))
                        .foregroundColor(.accentColor)
                    
                    Text("calendar.update_measurements".localized)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(formatDate(photo?.captureDate ?? selectedDate))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 30)
                .padding(.bottom, 40)
                
                // Input fields
                VStack(spacing: 25) {
                    // Weight input
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("calendar.weight".localized, systemImage: "scalemass")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if isLoadingHealthData {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        
                        HStack {
                            TextField("calendar.enter_weight".localized, text: $weightText)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .font(.title3)
                            
                            Text(userSettings.settings.weightUnit.symbol)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Body fat input
                    VStack(alignment: .leading, spacing: 8) {
                        Label("calendar.body_fat_optional".localized, systemImage: "percent")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            TextField("calendar.enter_body_fat".localized, text: $bodyFatText)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .font(.title3)
                            
                            Text("unit.percent".localized)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 15) {
                    Button(action: save) {
                        Text("common.save".localized)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentColor)
                            .cornerRadius(12)
                    }
                    .disabled(weightText.isEmpty)
                    
                    if photo?.weight != nil || photo?.bodyFatPercentage != nil {
                        Button(action: clear) {
                            Text("calendar.clear_data".localized)
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let photo = photo {
                if let weight = photo.weight {
                    weightText = String(format: "%.1f", convertWeight(weight))
                }
                if let bodyFat = photo.bodyFatPercentage {
                    bodyFatText = String(format: "%.1f", bodyFat)
                }
                
                // If no weight data and HealthKit is enabled, try to fetch it
                if photo.weight == nil && subscriptionManager.isPremium && userSettings.settings.healthKitEnabled {
                    fetchHealthKitData()
                }
            }
        }
    }
    
    private func save() {
        var weight: Double? = nil
        var bodyFat: Double? = nil
        
        if let weightValue = Double(weightText) {
            // Convert to kg if needed
            weight = userSettings.settings.weightUnit == .kg ? weightValue : weightValue / 2.20462
        }
        
        if !bodyFatText.isEmpty, let bodyFatValue = Double(bodyFatText) {
            bodyFat = bodyFatValue
        }
        
        onSave(weight, bodyFat)
        
        // Save to HealthKit if enabled
        if subscriptionManager.isPremium && userSettings.settings.healthKitEnabled {
            let saveDate = photo?.captureDate ?? selectedDate
            if let w = weight {
                HealthKitService.shared.saveWeight(w, date: saveDate) { _, _ in }
            }
            if let bf = bodyFat {
                HealthKitService.shared.saveBodyFatPercentage(bf, date: saveDate) { _, _ in }
            }
        }
        
        dismiss()
    }
    
    private func clear() {
        onSave(nil, nil)
        dismiss()
    }
    
    private func convertWeight(_ kg: Double) -> Double {
        userSettings.settings.weightUnit == .kg ? kg : kg * 2.20462
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        // Check current language and set appropriate format
        let currentLanguage = LanguageManager.shared.currentLanguage
        switch currentLanguage {
        case "ja":
            formatter.dateFormat = "yyyy/MM/dd"
        case "ko":
            formatter.dateFormat = "yyyy.MM.dd"
        default:
            formatter.dateFormat = "MMM d, yyyy"
        }
        
        return formatter.string(from: date)
    }
    
    private func fetchHealthKitData() {
        isLoadingHealthData = true
        
        // Fetch weight data from HealthKit
        HealthKitService.shared.fetchLatestWeight { weightKg, error in
            DispatchQueue.main.async {
                if let weightKg = weightKg {
                    self.weightText = String(format: "%.1f", self.convertWeight(weightKg))
                }
                
                // Also fetch body fat
                HealthKitService.shared.fetchLatestBodyFatPercentage { bodyFatPercent, error in
                    DispatchQueue.main.async {
                        if let bodyFatPercent = bodyFatPercent {
                            self.bodyFatText = String(format: "%.1f", bodyFatPercent)
                        }
                        self.isLoadingHealthData = false
                    }
                }
            }
        }
    }
}

struct VideoGenerationView: View {
    let period: CalendarView.TimePeriod
    let dateRange: [Date]
    @Binding var isGenerating: Bool
    let userSettings: UserSettingsManager
    let onGenerate: (VideoGenerationService.VideoGenerationOptions, Date, Date) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManagerService.shared
    @State private var selectedSpeed: VideoSpeed = .normal
    @State private var selectedQuality: VideoQuality = .standard
    @State private var enableFaceBlur = false
    @State private var showDateInVideo = true
    @State private var videoLayout: VideoGenerationService.VideoGenerationOptions.VideoLayout = .single
    @State private var selectedCategories: Set<String> = []
    @State private var availableCategories: [PhotoCategory] = []
    
    // Date range selection
    @State private var customStartDate: Date = Date()
    @State private var customEndDate: Date = Date()
    
    enum VideoSpeed: String, CaseIterable {
        case slow = "Slow (0.5s/frame)"
        case normal = "Normal (0.25s/frame)"
        case fast = "Fast (0.1s/frame)"
        
        var localizedString: String {
            switch self {
            case .slow: return "calendar.speed.slow".localized
            case .normal: return "calendar.speed.normal".localized
            case .fast: return "calendar.speed.fast".localized
            }
        }
        
        var frameDuration: CMTime {
            switch self {
            case .slow: return CMTime(value: 1, timescale: 2)
            case .normal: return CMTime(value: 1, timescale: 4)
            case .fast: return CMTime(value: 1, timescale: 10)
            }
        }
    }
    
    enum VideoQuality: String, CaseIterable {
        case standard = "Standard (720p)"
        case high = "High (1080p)"
        case ultra = "Ultra (4K)"
        
        var localizedString: String {
            switch self {
            case .standard: return "calendar.quality.standard".localized
            case .high: return "calendar.quality.high".localized
            case .ultra: return "calendar.quality.ultra".localized
            }
        }
        
        var videoSize: CGSize {
            switch self {
            case .standard: return CGSize(width: 720, height: 1280)
            case .high: return CGSize(width: 1080, height: 1920)
            case .ultra: return CGSize(width: 2160, height: 3840)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("calendar.period_label".localized)) {
                    // Show current period info
                    HStack {
                        Text("calendar.selected_period".localized)
                        Spacer()
                        Text(period.localizedString)
                            .foregroundColor(.secondary)
                    }
                    
                    // Always show date pickers
                    DatePicker("calendar.start_date".localized, 
                              selection: $customStartDate,
                              in: ...customEndDate,
                              displayedComponents: .date)
                    
                    DatePicker("calendar.end_date".localized,
                              selection: $customEndDate,
                              in: customStartDate...,
                              displayedComponents: .date)
                    
                    HStack {
                        Text("calendar.date_range".localized)
                        Spacer()
                        Text(formatDateRange(from: customStartDate, to: customEndDate))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Section(header: Text("calendar.video_settings".localized)) {
                    Picker("calendar.speed".localized, selection: $selectedSpeed) {
                        ForEach(VideoSpeed.allCases, id: \.self) { speed in
                            Text(speed.localizedString).tag(speed)
                        }
                    }
                    
                    Picker("calendar.quality".localized, selection: $selectedQuality) {
                        ForEach(VideoQuality.allCases, id: \.self) { quality in
                            Text(quality.localizedString).tag(quality)
                        }
                    }
                    
                    Toggle("calendar.blur_faces".localized, isOn: $enableFaceBlur)
                    
                    Toggle("calendar.show_date".localized, isOn: $showDateInVideo)
                    
                    // Video layout selection - Premium feature
                    if subscriptionManager.isPremium && availableCategories.count > 1 {
                        // Always use side-by-side layout for multiple categories
                        // Category selection for side-by-side
                        if videoLayout == .sideBySide {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("video.category.select".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ForEach(availableCategories) { category in
                                    HStack {
                                        Text(category.name)
                                        Spacer()
                                        if selectedCategories.contains(category.id) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.bodyLapseTurquoise)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        toggleCategory(category.id)
                                    }
                                }
                            }
                        }
                    }
                }
                
                if !subscriptionManager.isPremium {
                    Section {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("calendar.watermark_notice".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
            }
            .navigationTitle("calendar.generate_video".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                    .disabled(isGenerating)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("calendar.generate".localized) {
                        let options = VideoGenerationService.VideoGenerationOptions(
                            frameDuration: selectedSpeed.frameDuration,
                            videoSize: selectedQuality.videoSize,
                            addWatermark: !subscriptionManager.isPremium,
                            transitionStyle: .fade,
                            blurFaces: enableFaceBlur,
                            layout: videoLayout,
                            selectedCategories: Array(selectedCategories),
                            showDate: showDateInVideo
                        )
                        
                        // Show interstitial ad for free users
                        if !subscriptionManager.isPremium {
                            print("[VideoGeneration] Free user - showing ad before video generation")
                            dismiss()
                            
                            // Wait longer for dismissal to complete
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let window = windowScene.windows.first {
                                    
                                    // Find the topmost presented view controller
                                    var topController = window.rootViewController
                                    while let presented = topController?.presentedViewController {
                                        topController = presented
                                    }
                                    
                                    if let viewController = topController {
                                        print("[VideoGeneration] Found top view controller: \(type(of: viewController))")
                                        AdMobService.shared.showInterstitialAd(from: viewController) {
                                            print("[VideoGeneration] Interstitial ad closed - starting video generation")
                                            onGenerate(options, customStartDate, customEndDate)
                                        }
                                    } else {
                                        print("[VideoGeneration] Could not find view controller")
                                        onGenerate(options, customStartDate, customEndDate)
                                    }
                                } else {
                                    print("[VideoGeneration] Could not find window")
                                    onGenerate(options, customStartDate, customEndDate)
                                }
                            }
                        } else {
                            print("[VideoGeneration] Premium user - generating video without ad")
                            dismiss()
                            onGenerate(options, customStartDate, customEndDate)
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(countPhotosInRange() == 0)
                }
            }
        }
        .onAppear {
            // Initialize from user settings
            showDateInVideo = userSettings.settings.showDateInVideo
            
            // Initialize custom date range from current dateRange
            if let firstDate = dateRange.first {
                customStartDate = firstDate
            }
            if let lastDate = dateRange.last {
                customEndDate = lastDate
            }
            
            // Load available categories
            let isPremium = subscriptionManager.isPremium
            availableCategories = CategoryStorageService.shared.getActiveCategoriesForUser(isPremium: isPremium)
            
            // Set layout based on available categories
            if isPremium && availableCategories.count > 1 {
                // Multiple categories: use side-by-side
                videoLayout = .sideBySide
                // Select all categories by default (up to 4)
                selectedCategories = Set(availableCategories.prefix(4).map { $0.id })
            } else {
                // Single category: use single layout
                videoLayout = .single
                if let defaultCategory = availableCategories.first {
                    selectedCategories.insert(defaultCategory.id)
                }
            }
        }
    }
    
    private func countPhotosInRange() -> Int {
        let photos = PhotoStorageService.shared.photos
        
        return photos.filter { photo in
            photo.captureDate >= customStartDate && photo.captureDate <= customEndDate
        }.count
    }
    
    
    private func formatDateRange(from startDate: Date, to endDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let startString = formatter.string(from: startDate)
        let endString = formatter.string(from: endDate)
        
        if Calendar.current.isDate(startDate, equalTo: endDate, toGranularity: .year) {
            return "\(startString) - \(endString)"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
    }
    
    private func toggleCategory(_ categoryId: String) {
        if selectedCategories.contains(categoryId) {
            // Don't allow removing if it's the only selected category
            if selectedCategories.count > 1 {
                selectedCategories.remove(categoryId)
            }
        } else {
            // Limit to 4 categories
            if selectedCategories.count < 4 {
                selectedCategories.insert(categoryId)
            }
        }
    }
}

struct VideoGenerationProgressView: View {
    let progress: Float
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text("calendar.generating_video".localized)
                    .font(.headline)
                    .foregroundColor(.white)
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .frame(width: 200)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(15)
        }
    }
}

struct CustomDatePicker: UIViewRepresentable {
    @Binding var selection: Date
    let dateRange: ClosedRange<Date>
    let photoDates: Set<Date>
    let dataDates: Set<Date>
    
    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .inline
        picker.date = selection
        picker.minimumDate = dateRange.lowerBound
        picker.maximumDate = dateRange.upperBound
        
        picker.addTarget(context.coordinator, action: #selector(Coordinator.dateChanged(_:)), for: .valueChanged)
        
        // Customize the appearance
        DispatchQueue.main.async {
            self.addIndicators(to: picker)
        }
        
        return picker
    }
    
    func updateUIView(_ uiView: UIDatePicker, context: Context) {
        uiView.date = selection
        
        // Re-add indicators when view updates
        DispatchQueue.main.async {
            self.addIndicators(to: uiView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func addIndicators(to picker: UIDatePicker) {
        // Remove existing indicators
        picker.subviews.forEach { subview in
            subview.subviews.forEach { innerView in
                if innerView.tag == 999 {
                    innerView.removeFromSuperview()
                }
            }
        }
        
        // Find the calendar view
        guard let calendarView = findCalendarView(in: picker) else { return }
        
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d"
        
        // Add indicators for each visible date
        for subview in calendarView.subviews {
            findDateCells(in: subview) { cell, label in
                if let text = label.text,
                   let day = Int(text),
                   let cellDate = getDateForCell(day: day, in: picker) {
                    
                    let normalizedDate = calendar.startOfDay(for: cellDate)
                    let hasPhoto = photoDates.contains(normalizedDate)
                    let hasData = dataDates.contains(normalizedDate)
                    
                    if hasPhoto || hasData {
                        addIndicator(to: cell, hasPhoto: hasPhoto, hasData: hasData)
                    }
                }
            }
        }
    }
    
    private func findCalendarView(in view: UIView) -> UIView? {
        for subview in view.subviews {
            if String(describing: type(of: subview)).contains("Calendar") ||
               String(describing: type(of: subview)).contains("DatePicker") {
                return subview
            }
            if let found = findCalendarView(in: subview) {
                return found
            }
        }
        return nil
    }
    
    private func findDateCells(in view: UIView, completion: (UIView, UILabel) -> Void) {
        if let label = view as? UILabel {
            completion(view.superview ?? view, label)
        }
        
        for subview in view.subviews {
            findDateCells(in: subview, completion: completion)
        }
    }
    
    private func getDateForCell(day: Int, in picker: UIDatePicker) -> Date? {
        let calendar = Calendar.current
        let pickerComponents = calendar.dateComponents([.year, .month], from: picker.date)
        
        var components = DateComponents()
        components.year = pickerComponents.year
        components.month = pickerComponents.month
        components.day = day
        
        return calendar.date(from: components)
    }
    
    private func addIndicator(to cell: UIView, hasPhoto: Bool, hasData: Bool) {
        let indicatorSize: CGFloat = 6
        let spacing: CGFloat = 2
        
        let containerView = UIView()
        containerView.tag = 999
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.isUserInteractionEnabled = false
        
        var indicators: [UIView] = []
        
        if hasPhoto {
            let photoIndicator = UIView()
            photoIndicator.backgroundColor = UIColor(red: 0, green: 0.7, blue: 0.8, alpha: 1) // Turquoise
            photoIndicator.layer.cornerRadius = indicatorSize / 2
            photoIndicator.translatesAutoresizingMaskIntoConstraints = false
            indicators.append(photoIndicator)
        }
        
        if hasData {
            let dataIndicator = UIView()
            dataIndicator.backgroundColor = UIColor(red: 1, green: 0.82, blue: 0, alpha: 1) // Yellow
            dataIndicator.layer.cornerRadius = indicatorSize / 2
            dataIndicator.translatesAutoresizingMaskIntoConstraints = false
            indicators.append(dataIndicator)
        }
        
        cell.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
            containerView.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -2),
            containerView.heightAnchor.constraint(equalToConstant: indicatorSize)
        ])
        
        for (index, indicator) in indicators.enumerated() {
            containerView.addSubview(indicator)
            
            NSLayoutConstraint.activate([
                indicator.widthAnchor.constraint(equalToConstant: indicatorSize),
                indicator.heightAnchor.constraint(equalToConstant: indicatorSize),
                indicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
            ])
            
            if indicators.count == 1 {
                indicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor).isActive = true
            } else {
                let offset = CGFloat(index) * (indicatorSize + spacing) - (indicatorSize + spacing) / 2
                indicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor, constant: offset).isActive = true
            }
        }
        
        let totalWidth = CGFloat(indicators.count) * indicatorSize + CGFloat(indicators.count - 1) * spacing
        containerView.widthAnchor.constraint(equalToConstant: totalWidth).isActive = true
    }
    
    class Coordinator: NSObject {
        var parent: CustomDatePicker
        
        init(_ parent: CustomDatePicker) {
            self.parent = parent
        }
        
        @objc func dateChanged(_ sender: UIDatePicker) {
            parent.selection = sender.date
        }
    }
}