import SwiftUI
import AVFoundation

struct VideoGenerationView: View {
    let period: TimePeriod
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
    @State private var showGraphInVideo = true
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
                    
                    // Show graph toggle - Available for all users
                    Toggle("calendar.show_graph".localized, isOn: $showGraphInVideo)
                    
                    // Video layout selection - Available for all users
                    if availableCategories.count > 1 {
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
                
                // Watermark notice removed - no watermark for any users
                
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
                            addWatermark: false, // No watermark for any users
                            transitionStyle: .fade,
                            blurFaces: enableFaceBlur,
                            layout: videoLayout,
                            selectedCategories: Array(selectedCategories),
                            showDate: showDateInVideo,
                            showGraph: showGraphInVideo, // Available for all users
                            isWeightInLbs: userSettings.settings.weightUnit == .lbs
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
            availableCategories = CategoryStorageService.shared.getActiveCategoriesForUser(isPremium: true) // All users get full categories
            
            // Set layout based on available categories
            if availableCategories.count > 1 {
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