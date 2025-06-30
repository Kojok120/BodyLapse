import SwiftUI
import AVFoundation

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
    @State private var dragOffset: CGFloat = 0
    @State private var selectedIndex: Int = 0
    @State private var showingVideoGeneration = false
    @State private var isGeneratingVideo = false
    @State private var videoGenerationProgress: Float = 0
    @State private var showingVideoAlert = false
    @State private var videoAlertMessage = ""
    @State private var selectedChartDate: Date? = nil
    
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
        VStack(spacing: 6) {
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
        
        // Reload photos to ensure we have the latest
        viewModel.loadPhotos()
        updateCurrentPhoto()
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
            onGenerate: { options in
                generateVideo(with: options)
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
                            Text("calendar.has_data".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
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
        
        for entry in weightViewModel.weightEntries {
            if entry.weight > 0 || entry.bodyFatPercentage != nil {
                if let date = calendar.dateInterval(of: .day, for: entry.date)?.start {
                    dataDates.insert(date)
                }
            }
        }
        
        return dataDates
    }
    
    private var headerView: some View {
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
        .padding(.vertical, 8)
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
            
            GeometryReader { geometry in
                if let photo = currentPhoto,
                   let uiImage = PhotoStorageService.shared.loadImage(for: photo) {
                    VStack {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width)
                            .cornerRadius(12)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("calendar.no_photo".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .frame(height: subscriptionManager.isPremium ? UIScreen.main.bounds.height * 0.38 : UIScreen.main.bounds.height * 0.46)
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
                            
                            Rectangle()
                                .fill(hasPhoto ? Color.accentColor : Color.clear)
                                .frame(width: geometry.size.width / CGFloat(dateRange.count))
                                .overlay(
                                    Rectangle()
                                        .stroke(Color(UIColor.systemGray4), lineWidth: 0.5)
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
            
            Text(formatDateRange())
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical)
    }
    
    private var dataGraphSection: some View {
        VStack(spacing: 6) {
            if !weightViewModel.weightEntries.isEmpty {
                if #available(iOS 16.0, *) {
                    let filteredEntries = weightViewModel.filteredEntries(for: getWeightTimeRange())
                    if !filteredEntries.isEmpty {
                        let fullRange: ClosedRange<Date> = {
                            if let first = dateRange.first, let last = dateRange.last {
                                return first...last
                            } else {
                                return Date()...Date()
                            }
                        }()
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
                        Text("calendar.no_data_period".localized)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(15)
                    }
                } else {
                    Text("calendar.ios16_required".localized)
                        .foregroundColor(.secondary)
                        .padding()
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("calendar.no_weight_data".localized)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("calendar.add_weight_hint".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("calendar.reload_data".localized) {
                        weightViewModel.loadEntries()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding()
                .frame(minHeight: 200)
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
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func formatDateRange() -> String {
        guard let firstDate = dateRange.first,
              let lastDate = dateRange.last else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        return "\(formatter.string(from: firstDate)) - \(formatter.string(from: lastDate))"
    }
    
    private func updateCurrentPhoto() {
        currentPhoto = viewModel.photos.first { photo in
            Calendar.current.isDate(photo.captureDate, inSameDayAs: selectedDate)
        }
    }
    
    private func generateVideo(with options: VideoGenerationService.VideoGenerationOptions) {
        isGeneratingVideo = true
        videoGenerationProgress = 0
        
        let startDate = dateRange.first ?? Date()
        let endDate = dateRange.last ?? Date()
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
                            
                            Text("%")
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
        formatter.dateFormat = "MMM d, yyyy"
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
    let onGenerate: (VideoGenerationService.VideoGenerationOptions) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManagerService.shared
    @State private var selectedSpeed: VideoSpeed = .normal
    @State private var selectedQuality: VideoQuality = .high
    @State private var enableFaceBlur = false
    
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
                    HStack {
                        Text("calendar.selected_period".localized)
                        Spacer()
                        Text(period.localizedString)
                            .foregroundColor(.secondary)
                    }
                    
                    if let firstDate = dateRange.first,
                       let lastDate = dateRange.last {
                        HStack {
                            Text("calendar.date_range".localized)
                            Spacer()
                            Text(formatDateRange(from: firstDate, to: lastDate))
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    let photoCount = countPhotosInRange()
                    HStack {
                        Text("calendar.photos".localized)
                        Spacer()
                        Text("\(photoCount)")
                            .foregroundColor(.secondary)
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
                
                Section {
                    let estimatedDuration = estimateDuration()
                    HStack {
                        Text("calendar.estimated_duration".localized)
                        Spacer()
                        Text(estimatedDuration)
                            .foregroundColor(.secondary)
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
                            blurFaces: enableFaceBlur
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
                                            onGenerate(options)
                                        }
                                    } else {
                                        print("[VideoGeneration] Could not find view controller")
                                        onGenerate(options)
                                    }
                                } else {
                                    print("[VideoGeneration] Could not find window")
                                    onGenerate(options)
                                }
                            }
                        } else {
                            print("[VideoGeneration] Premium user - generating video without ad")
                            dismiss()
                            onGenerate(options)
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(countPhotosInRange() == 0)
                }
            }
        }
    }
    
    private func countPhotosInRange() -> Int {
        let photos = PhotoStorageService.shared.photos
        let startDate = dateRange.first ?? Date()
        let endDate = dateRange.last ?? Date()
        
        return photos.filter { photo in
            photo.captureDate >= startDate && photo.captureDate <= endDate
        }.count
    }
    
    private func estimateDuration() -> String {
        let photoCount = countPhotosInRange()
        let frameDuration = selectedSpeed.frameDuration.seconds
        let totalSeconds = Double(photoCount) * frameDuration
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        
        return formatter.string(from: totalSeconds) ?? "0s"
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