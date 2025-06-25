import SwiftUI
import AVFoundation

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @StateObject private var userSettings = UserSettingsManager()
    @StateObject private var weightViewModel = WeightTrackingViewModel()
    @State private var selectedDate = Date()
    @State private var showingPeriodPicker = false
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
    @State private var showingCalendarPopup = false
    @State private var showingImagePicker = false
    
    enum TimePeriod: String, CaseIterable {
        case week = "7 Days"
        case month = "30 Days"
        case threeMonths = "3 Months"
        case sixMonths = "6 Months"
        case year = "1 Year"
        
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
            VStack(spacing: 12) {
                headerView
                
                photoPreviewSection
                
                if userSettings.settings.isPremium {
                    dataGraphSection
                } else {
                    progressBarSection
                }
            }
            .withBannerAd()
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.loadPhotos()
                weightViewModel.loadEntries()
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
                    print("[Calendar] Is premium: \(userSettings.settings.isPremium)")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToCalendarToday"))) { _ in
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
            .onChange(of: selectedDate) { newDate in
                updateCurrentPhoto()
                selectedChartDate = newDate  // Sync chart selection when date changes
            }
            .sheet(isPresented: $showingWeightInput) {
                WeightInputView(photo: $currentPhoto, onSave: { weight, bodyFat in
                    if let photo = currentPhoto {
                        PhotoStorageService.shared.updatePhotoMetadata(photo, weight: weight, bodyFatPercentage: bodyFat)
                        viewModel.loadPhotos()
                        updateCurrentPhoto()
                        
                        // Also save to weight tracking
                        if let w = weight {
                            let entry = WeightEntry(
                                date: photo.captureDate,
                                weight: w,
                                bodyFatPercentage: bodyFat,
                                linkedPhotoID: photo.id.uuidString
                            )
                            Task {
                                try? await WeightStorageService.shared.saveEntry(entry)
                                await MainActor.run {
                                    weightViewModel.loadEntries()
                                }
                            }
                        }
                    }
                })
            }
            .sheet(isPresented: $showingVideoGeneration) {
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
                    if !userSettings.settings.isPremium {
                        print("[VideoGenerationView] Sheet appeared - checking ad status")
                        AdMobService.shared.checkAdStatus()
                        AdMobService.shared.loadInterstitialAd()
                    }
                }
            }
            .alert("Video Generation", isPresented: $showingVideoAlert) {
                Button("OK") { }
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
            .sheet(isPresented: $showingCalendarPopup) {
                CalendarPopupView(
                    selectedDate: $selectedDate,
                    photos: viewModel.photos,
                    onDateSelected: { date in
                        selectedDate = date
                        selectedChartDate = date  // Sync chart selection
                        if let index = dateRange.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: date) }) {
                            selectedIndex = index
                        }
                        updateCurrentPhoto()
                        showingCalendarPopup = false
                    }
                )
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: .constant(nil)) { image in
                    if let image = image {
                        // Save the imported image for the selected date
                        print("[CalendarView] Saving photo for date: \(selectedDate)")
                        do {
                            let savedPhoto = try PhotoStorageService.shared.replacePhoto(
                                for: selectedDate,
                                with: image,
                                isFaceBlurred: false,
                                bodyDetectionConfidence: 0.0
                            )
                            print("[CalendarView] Photo saved successfully with date: \(savedPhoto.captureDate)")
                        } catch {
                            print("[CalendarView] Error saving imported photo: \(error)")
                        }
                        viewModel.loadPhotos()
                        updateCurrentPhoto()
                    }
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            HStack(spacing: 8) {
                Button(action: {
                    showingPeriodPicker = true
                }) {
                    HStack {
                        Text(selectedPeriod.rawValue)
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
                    showingCalendarPopup = true
                }) {
                    Image(systemName: "calendar")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                }
            }
            .actionSheet(isPresented: $showingPeriodPicker) {
                ActionSheet(
                    title: Text("Select Time Period"),
                    buttons: TimePeriod.allCases.map { period in
                        .default(Text(period.rawValue)) {
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
                    Text("Generate")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .cornerRadius(20)
            }
            .disabled(isGeneratingVideo)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    private var photoPreviewSection: some View {
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
                    Text("No photo for \(formatDate(selectedDate))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        Label("Upload Photo", systemImage: "photo.badge.plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.accentColor)
                            .cornerRadius(20)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .frame(height: userSettings.settings.isPremium ? UIScreen.main.bounds.height * 0.35 : UIScreen.main.bounds.height * 0.5)
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
                            x: (geometry.size.width / CGFloat(dateRange.count)) * CGFloat(selectedIndex) + (geometry.size.width / CGFloat(dateRange.count) / 2),
                            y: 30
                        )
                }
                .frame(height: 60)
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
            }
            .frame(height: 60)
            .padding(.horizontal)
            
            Text(formatDateRange())
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical)
    }
    
    private var dataGraphSection: some View {
        VStack(spacing: 10) {
            if !weightViewModel.weightEntries.isEmpty {
                if #available(iOS 16.0, *) {
                    let filteredEntries = weightViewModel.filteredEntries(for: getWeightTimeRange())
                    if !filteredEntries.isEmpty {
                        InteractiveWeightChartView(
                            entries: filteredEntries,
                            selectedDate: $selectedChartDate,
                            currentPhoto: currentPhoto,
                            onEditWeight: {
                                showingWeightInput = true
                            }
                        )
                        .padding(.horizontal)
                        .onChange(of: selectedChartDate) { newDate in
                            if let date = newDate {
                                // Update selected date in calendar when chart date changes
                                if let index = dateRange.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: date) }) {
                                    selectedIndex = index
                                    selectedDate = date
                                }
                            }
                        }
                        .onChange(of: selectedPeriod) { _ in
                            // Reset chart selection when period changes
                            selectedChartDate = nil
                        }
                    } else {
                        Text("No data for selected period")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(15)
                    }
                } else {
                    Text("Weight tracking requires iOS 16 or later")
                        .foregroundColor(.secondary)
                        .padding()
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("No weight data yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Add weight data when saving photos")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Reload Data") {
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
    let onSave: (Double?, Double?) -> Void
    
    @State private var weightText = ""
    @State private var bodyFatText = ""
    @StateObject private var userSettings = UserSettingsManager()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "scalemass")
                        .font(.system(size: 50))
                        .foregroundColor(.accentColor)
                    
                    Text("Update Measurements")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let photo = photo {
                        Text(formatDate(photo.captureDate))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 30)
                .padding(.bottom, 40)
                
                // Input fields
                VStack(spacing: 25) {
                    // Weight input
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Weight", systemImage: "scalemass")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            TextField("Enter weight", text: $weightText)
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
                        Label("Body Fat % (Optional)", systemImage: "percent")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            TextField("Enter body fat", text: $bodyFatText)
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
                        Text("Save")
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
                            Text("Clear Data")
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
                    Button("Cancel") {
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
}

struct VideoGenerationView: View {
    let period: CalendarView.TimePeriod
    let dateRange: [Date]
    @Binding var isGenerating: Bool
    let userSettings: UserSettingsManager
    let onGenerate: (VideoGenerationService.VideoGenerationOptions) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSpeed: VideoSpeed = .normal
    @State private var selectedQuality: VideoQuality = .high
    @State private var enableFaceBlur = false
    
    enum VideoSpeed: String, CaseIterable {
        case slow = "Slow (0.5s/frame)"
        case normal = "Normal (0.25s/frame)"
        case fast = "Fast (0.1s/frame)"
        
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
                Section(header: Text("Period")) {
                    HStack {
                        Text("Selected Period")
                        Spacer()
                        Text(period.rawValue)
                            .foregroundColor(.secondary)
                    }
                    
                    if let firstDate = dateRange.first,
                       let lastDate = dateRange.last {
                        HStack {
                            Text("Date Range")
                            Spacer()
                            Text(formatDateRange(from: firstDate, to: lastDate))
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    let photoCount = countPhotosInRange()
                    HStack {
                        Text("Photos")
                        Spacer()
                        Text("\(photoCount)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Video Settings")) {
                    Picker("Speed", selection: $selectedSpeed) {
                        ForEach(VideoSpeed.allCases, id: \.self) { speed in
                            Text(speed.rawValue).tag(speed)
                        }
                    }
                    
                    Picker("Quality", selection: $selectedQuality) {
                        ForEach(VideoQuality.allCases, id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    
                    Toggle("Blur Faces", isOn: $enableFaceBlur)
                }
                
                if !userSettings.settings.isPremium {
                    Section {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Free version includes a watermark")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    let estimatedDuration = estimateDuration()
                    HStack {
                        Text("Estimated Duration")
                        Spacer()
                        Text(estimatedDuration)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Generate Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isGenerating)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Generate") {
                        let options = VideoGenerationService.VideoGenerationOptions(
                            frameDuration: selectedSpeed.frameDuration,
                            videoSize: selectedQuality.videoSize,
                            addWatermark: !userSettings.settings.isPremium,
                            transitionStyle: .fade,
                            blurFaces: enableFaceBlur
                        )
                        
                        // Show interstitial ad for free users
                        if !userSettings.settings.isPremium {
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
                Text("Generating Video")
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