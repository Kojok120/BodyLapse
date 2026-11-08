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
                Section(
                    header: Text("calendar.period_label".localized),
                    footer: Group {
                        if photoCountInRange == 0 {
                            Text("calendar.video_no_photos_in_range".localized)
                                .foregroundColor(.red)
                        }
                    }
                ) {
                    // 既定は全期間。カレンダーで表示中の期間にも切り替えられる
                    HStack(spacing: 12) {
                        Button("calendar.video_range_all".localized, action: applyFullRange)
                            .buttonStyle(.bordered)
                        if let first = dateRange.first, let last = dateRange.last {
                            Button("calendar.video_range_calendar".localized(with: period.localizedString)) {
                                customStartDate = first
                                customEndDate = last
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .font(.subheadline)
                    
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
                        Text("calendar.photos_in_range".localized)
                        Spacer()
                        Text("gallery.photos_count".localized(with: photoCountInRange))
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
                    .disabled(photoCountInRange == 0)
                }
            }
        }
        .onAppear {
            // Initialize from user settings
            showDateInVideo = userSettings.settings.showDateInVideo
            
            // Load available categories
            availableCategories = CategoryStorageService.shared.getActiveCategories()
            
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

            // 既定の期間は全期間 (カレンダーの既定の 1 週間だと約 2 秒の動画になっていた)
            applyFullRange()
        }
    }
    
    /// 動画に使うカテゴリ (単一レイアウトでは先頭の 1 つ)
    private var categoryIdsForVideo: Set<String> {
        if videoLayout == .sideBySide {
            return selectedCategories
        }
        return selectedCategories.first.map { [$0] } ?? []
    }

    private var photoCountInRange: Int {
        VideoRangePlanner.photoCount(
            photos: PhotoStorageService.shared.photos,
            from: customStartDate,
            to: customEndDate,
            categoryIds: categoryIdsForVideo
        )
    }

    private func applyFullRange() {
        let range = VideoRangePlanner.defaultRange(
            photos: PhotoStorageService.shared.photos,
            categoryIds: categoryIdsForVideo,
            today: Date()
        )
        customStartDate = range.lowerBound
        customEndDate = range.upperBound
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
                // 明るいカードに白い文字で、ほぼ読めなかった (1.12:1)
                Text("calendar.generating_video".localized)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .bodyLapseTurquoise))
                    .frame(width: 200)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(30)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(15)
        }
    }
}