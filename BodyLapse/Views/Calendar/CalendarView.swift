import SwiftUI
import AVFoundation

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @StateObject private var userSettings = UserSettingsManager()
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
            VStack(spacing: 0) {
                headerView
                
                photoPreviewSection
                
                if userSettings.settings.isPremium {
                    dataGraphSection
                } else {
                    progressBarSection
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.loadPhotos()
                updateCurrentPhoto()
            }
            .onChange(of: selectedDate) { _ in
                updateCurrentPhoto()
            }
            .sheet(isPresented: $showingWeightInput) {
                WeightInputView(photo: $currentPhoto, onSave: { weight, bodyFat in
                    if let photo = currentPhoto {
                        PhotoStorageService.shared.updatePhotoMetadata(photo, weight: weight, bodyFatPercentage: bodyFat)
                        viewModel.loadPhotos()
                        updateCurrentPhoto()
                    }
                })
            }
            .sheet(isPresented: $showingVideoGeneration) {
                VideoGenerationView(
                    period: selectedPeriod,
                    dateRange: dateRange,
                    isGenerating: $isGeneratingVideo,
                    onGenerate: { options in
                        generateVideo(with: options)
                    }
                )
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
        }
    }
    
    private var headerView: some View {
        HStack {
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
            .actionSheet(isPresented: $showingPeriodPicker) {
                ActionSheet(
                    title: Text("Select Time Period"),
                    buttons: TimePeriod.allCases.map { period in
                        .default(Text(period.rawValue)) {
                            selectedPeriod = period
                            selectedIndex = dateRange.count - 1
                            selectedDate = dateRange[selectedIndex]
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
        .padding()
    }
    
    private var photoPreviewSection: some View {
        VStack {
            if let photo = currentPhoto,
               let uiImage = PhotoStorageService.shared.loadImage(for: photo) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.4)
                    .cornerRadius(12)
                    .padding(.horizontal)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text(formatDate(selectedDate))
                            .font(.headline)
                        
                        if userSettings.settings.isPremium {
                            HStack {
                                if let weight = photo.weight {
                                    Label("\(String(format: "%.1f", weight)) \(userSettings.settings.weightUnit.symbol)", systemImage: "scalemass")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if let bodyFat = photo.bodyFatPercentage {
                                    Label("\(String(format: "%.1f", bodyFat))%", systemImage: "percent")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    if userSettings.settings.isPremium {
                        Button(action: {
                            showingWeightInput = true
                        }) {
                            Image(systemName: photo.weight != nil ? "pencil.circle.fill" : "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            } else {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No photo for \(formatDate(selectedDate))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: UIScreen.main.bounds.height * 0.4)
            }
        }
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
        VStack {
            // TODO: Implement weight and body fat graphs for premium users
            Text("Premium data visualization coming soon")
                .foregroundColor(.secondary)
                .padding()
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
                    case .success:
                        self.videoAlertMessage = "Video generated successfully! You can view it in the Gallery."
                        self.showingVideoAlert = true
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
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userSettings = UserSettingsManager()
    
    @State private var weightText = ""
    @State private var bodyFatText = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Measurements")) {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("0.0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text(userSettings.settings.weightUnit.symbol)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Body Fat")
                        Spacer()
                        TextField("0.0", text: $bodyFatText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("%")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Add Measurements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let weight = Double(weightText)
                        let bodyFat = Double(bodyFatText)
                        onSave(weight, bodyFat)
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let photo = photo {
                    if let weight = photo.weight {
                        weightText = String(format: "%.1f", weight)
                    }
                    if let bodyFat = photo.bodyFatPercentage {
                        bodyFatText = String(format: "%.1f", bodyFat)
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
    let onGenerate: (VideoGenerationService.VideoGenerationOptions) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userSettings = UserSettingsManager()
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
                        onGenerate(options)
                        dismiss()
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