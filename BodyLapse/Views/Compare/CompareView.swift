import SwiftUI

struct CompareView: View {
    @StateObject private var viewModel = CompareViewModel()
    @StateObject private var userSettings = UserSettingsManager.shared
    @StateObject private var subscriptionManager = SubscriptionManagerService.shared
    @State private var firstPhoto: Photo?
    @State private var secondPhoto: Photo?
    @State private var firstSelectedDate: Date?
    @State private var secondSelectedDate: Date?
    @State private var showingFirstCalendar = false
    @State private var showingSecondCalendar = false
    @State private var availableCategories: [PhotoCategory] = []
    @State private var firstCategory: PhotoCategory = PhotoCategory.defaultCategory
    @State private var secondCategory: PhotoCategory = PhotoCategory.defaultCategory
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var showingShareError = false
    @State private var showingShareHint = false
    @State private var showingProPaywall = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 写真選択 buttons
                    photoSelectionButtons
                    
                    // Divider
                    Divider()
                        .background(Color.bodyLapseLightGray)
                        .padding(.horizontal)
                    
                    // Main comparison view
                    if firstPhoto != nil || secondPhoto != nil {
                        comparisonView
                    } else {
                        emptyStateView
                    }
                }
                
                // Banner ad at bottom
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 50)
                        .modifier(BannerAdModifier())
                }
            }
            .navigationTitle("compare.title".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        shareTapped()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(firstPhoto == nil || secondPhoto == nil)
                    .accessibilityLabel("compare.share".localized)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: shareItems)
            }
            .alert("share.error.title".localized, isPresented: $showingShareError) {
                Button("common.ok".localized) {}
            } message: {
                Text("share.error.load_failed".localized)
            }
            .alert("paywall.share.title".localized, isPresented: $showingShareHint) {
                Button("paywall.share_anyway".localized) { performShare() }
                Button("paywall.view_pro".localized) { showingProPaywall = true }
            } message: {
                Text("paywall.share.message".localized)
            }
            .sheet(isPresented: $showingProPaywall) {
                PremiumView()
            }
            .sheet(isPresented: $showingFirstCalendar) {
                CalendarPopupView(
                    selectedDate: Binding(
                        get: { firstSelectedDate ?? firstPhoto?.captureDate ?? Date() },
                        set: { _ in }
                    ),
                    photos: viewModel.photos,
                    onDateSelected: { date in
                        firstPhoto = viewModel.photo(on: date, categoryId: firstCategory.id)
                        firstSelectedDate = date
                        showingFirstCalendar = false
                    },
                    minDate: nil,
                    maxDate: secondSelectedDate,
                    categoryId: firstCategory.id
                )
            }
            .sheet(isPresented: $showingSecondCalendar) {
                CalendarPopupView(
                    selectedDate: Binding(
                        get: { secondSelectedDate ?? secondPhoto?.captureDate ?? Date() },
                        set: { _ in }
                    ),
                    photos: viewModel.photos,
                    onDateSelected: { date in
                        secondPhoto = viewModel.photo(on: date, categoryId: secondCategory.id)
                        secondSelectedDate = date
                        showingSecondCalendar = false
                    },
                    minDate: firstSelectedDate,
                    maxDate: nil,
                    categoryId: secondCategory.id
                )
            }
        }
        .onAppear {
            reloadData()
            availableCategories = CategoryStorageService.shared.getActiveCategories()
            applyDefaultPairIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            reloadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PhotosUpdated"))) { _ in
            reloadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("WeightDataSyncComplete"))) { _ in
            reloadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HealthKitDataSynced"))) { _ in
            reloadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("GuidelineUpdated"))) { _ in
            reloadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CategoriesUpdated"))) { _ in
            availableCategories = CategoryStorageService.shared.getActiveCategories()
            
            // 選んでいたカテゴリが消えていたら先頭に戻す
            if !availableCategories.contains(where: { $0.id == firstCategory.id }) {
                firstCategory = availableCategories.first ?? PhotoCategory.defaultCategory
                firstPhoto = nil
                firstSelectedDate = nil
            }
            
            if !availableCategories.contains(where: { $0.id == secondCategory.id }) {
                secondCategory = availableCategories.first ?? PhotoCategory.defaultCategory
                secondPhoto = nil
                secondSelectedDate = nil
            }
            applyDefaultPairIfNeeded()
        }
    }

    // MARK: - Data

    /// 写真一覧と体重の記録を読み直し、選んでいる写真を最新の内容に差し替える
    private func reloadData() {
        viewModel.refresh()
        if let date = firstSelectedDate {
            firstPhoto = viewModel.photo(on: date, categoryId: firstCategory.id)
        }
        if let date = secondSelectedDate {
            secondPhoto = viewModel.photo(on: date, categoryId: secondCategory.id)
        }
    }

    /// 何も選んでいなければ、最も古い写真と最も新しい写真で開く
    private func applyDefaultPairIfNeeded() {
        guard firstPhoto == nil, secondPhoto == nil else { return }
        let before = ComparePairing.defaultPair(from: viewModel.photos, categoryId: firstCategory.id).before
        let after = ComparePairing.defaultPair(from: viewModel.photos, categoryId: secondCategory.id).after
        firstPhoto = before
        firstSelectedDate = before?.captureDate
        secondPhoto = after
        secondSelectedDate = after?.captureDate
    }
    
    private var comparisonView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 写真と体重・体脂肪率
                HStack(alignment: .top, spacing: 2) {
                    VStack(spacing: 0) {
                        comparisonPhotoContent(photo: firstPhoto)
                            .frame(height: 250)
                        measurementBox(for: firstPhoto)
                    }
                    
                    Rectangle()
                        .fill(Color.bodyLapseLightGray)
                        .frame(width: 2)
                    
                    VStack(spacing: 0) {
                        comparisonPhotoContent(photo: secondPhoto)
                            .frame(height: 250)
                        measurementBox(for: secondPhoto)
                    }
                }
                .padding(.horizontal, 2)
                
                // 差分
                if let first = firstPhoto, let second = secondPhoto {
                    differenceSummary(first: first, second: second)
                        .padding(.horizontal)
                        .padding(.top, 16)
                }
                
                Spacer()
                    .frame(height: 100)
            }
            .padding(.bottom, 60) // Space for banner ad
        }
    }

    private func measurementBox(for photo: Photo?) -> some View {
        VStack(spacing: 4) {
            if let photo {
                HStack(spacing: 4) {
                    Image(systemName: "scalemass")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    if let weight = viewModel.weight(for: photo) {
                        Text("\(convertedWeight(weight), specifier: "%.1f") \(userSettings.settings.weightUnit.symbol)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    } else {
                        Text("compare.no_weight".localized)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                if let bodyFat = viewModel.bodyFat(for: photo) {
                    HStack(spacing: 4) {
                        Image(systemName: "percent")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("\(bodyFat, specifier: "%.1f")%")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("compare.select_photo".localized)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .padding(.top, 4)
    }

    @ViewBuilder
    private func differenceSummary(first: Photo, second: Photo) -> some View {
        let weightDiff = ComparePairing.difference(before: viewModel.weight(for: first), after: viewModel.weight(for: second))
        let bodyFatDiff = ComparePairing.difference(before: viewModel.bodyFat(for: first), after: viewModel.bodyFat(for: second))
        if weightDiff != nil || bodyFatDiff != nil {
            HStack(spacing: 20) {
                if let weightDiff {
                    VStack(spacing: 4) {
                        HStack(spacing: 2) {
                            Image(systemName: weightDiff > 0 ? "arrow.up" : "arrow.down")
                                .font(.caption)
                            Text("\(abs(convertedWeight(weightDiff)), specifier: "%.1f") \(userSettings.settings.weightUnit.symbol)")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(weightDiff > 0 ? .red : .green)
                        Text("compare.weight".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let bodyFatDiff {
                    if weightDiff != nil {
                        Divider()
                            .frame(height: 30)
                    }
                    
                    VStack(spacing: 4) {
                        HStack(spacing: 2) {
                            Image(systemName: bodyFatDiff > 0 ? "arrow.up" : "arrow.down")
                                .font(.caption)
                            Text("\(abs(bodyFatDiff), specifier: "%.1f")%")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(bodyFatDiff > 0 ? .red : .green)
                        Text("compare.body_fat".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(10)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("compare.instruction".localized)
                .font(.headline)
                .foregroundColor(.primary)
            Text("compare.select_two_photos".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var photoSelectionButtons: some View {
        VStack(spacing: 16) {
            // カテゴリが複数あるときは左右それぞれ選べる
            if availableCategories.count > 1 {
                HStack(spacing: 20) {
                    categoryMenu(title: "compare.before".localized, selection: firstCategory) { category in
                        firstCategory = category
                        if let date = firstSelectedDate {
                            firstPhoto = viewModel.photo(on: date, categoryId: category.id)
                        }
                    }
                    categoryMenu(title: "compare.after".localized, selection: secondCategory) { category in
                        secondCategory = category
                        if let date = secondSelectedDate {
                            secondPhoto = viewModel.photo(on: date, categoryId: category.id)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Date selection buttons
            HStack(spacing: 20) {
                Button(action: {
                    showingFirstCalendar = true
                }) {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "calendar")
                            Text("compare.before".localized)
                        }
                        .font(.headline)
                        
                        if let date = firstSelectedDate {
                            Text(formatDate(date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("compare.select_date".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                }
                
                Button(action: {
                    showingSecondCalendar = true
                }) {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "calendar")
                            Text("compare.after".localized)
                        }
                        .font(.headline)
                        
                        if let date = secondSelectedDate {
                            Text(formatDate(date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("compare.select_date".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal)
        }
        .padding(.top)
    }

    private func categoryMenu(title: String, selection: PhotoCategory, onSelect: @escaping (PhotoCategory) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Menu {
                ForEach(availableCategories) { category in
                    Button {
                        onSelect(category)
                    } label: {
                        Label(category.name, systemImage: selection.id == category.id ? "checkmark" : "")
                    }
                }
            } label: {
                HStack {
                    Text(selection.name)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.tertiarySystemFill))
                .cornerRadius(8)
            }
        }
    }

    private var comparisonPhotoWidth: CGFloat {
        (UIScreen.main.bounds.width - 6) / 2
    }

    @ViewBuilder
    private func comparisonPhotoContent(photo: Photo?) -> some View {
        if let photo {
            StoredPhotoImageView(photo: photo, contentMode: .fill) {
                comparisonPhotoPlaceholder
            }
            .frame(width: comparisonPhotoWidth, height: 250)
            .clipped()
        } else {
            comparisonPhotoPlaceholder
        }
    }

    private var comparisonPhotoPlaceholder: some View {
        Rectangle()
            .fill(Color(UIColor.systemGray5))
            .frame(width: comparisonPhotoWidth, height: 250)
            .overlay(
                Image("compare-placeholder-image")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: comparisonPhotoWidth, height: 250)
                    .opacity(0.3)
            )
    }
    
    private func formatDate(_ date: Date) -> String {
        AppDateFormat.medium(date)
    }
    
    private func convertedWeight(_ weight: Double) -> Double {
        MeasurementInput.displayWeight(kg: weight, unit: userSettings.settings.weightUnit)
    }

    /// 選択中の2枚からビフォーアフター共有画像を生成して共有シートを表示する。
    /// 全ユーザー利用可。Pro以外はウォーターマークを付与する。
    /// 共有ボタンのタップ入口。非Proには初回のみ透かしヒントを挟み、以降はそのまま共有する。
    private func shareTapped() {
        if !subscriptionManager.isPro, !PaywallPromptManager.shared.hasShown(.shareWatermark) {
            PaywallPromptManager.shared.markShown(.shareWatermark)
            showingShareHint = true
        } else {
            performShare()
        }
    }

    private func performShare() {
        guard let first = firstPhoto, let second = secondPhoto else { return }

        // 日付の早い方を「変化前」、遅い方を「変化後」にする
        let beforeIsFirst = first.captureDate <= second.captureDate
        let beforePhoto = beforeIsFirst ? first : second
        let afterPhoto = beforeIsFirst ? second : first

        let isPro = subscriptionManager.isPro
        let beforeLabel = "compare.before".localized
        let afterLabel = "compare.after".localized
        let beforeDateText = AppDateFormat.medium(beforePhoto.captureDate)
        let afterDateText = AppDateFormat.medium(afterPhoto.captureDate)

        // 重い画像ロード/合成はバックグラウンドで行い、UI更新のみメインに戻す（共有ボタン押下時のUIフリーズを防ぐ）
        DispatchQueue.global(qos: .userInitiated).async {
            let targetSize = CGSize(width: 1080, height: 1350)
            guard let beforeImage = PhotoStorageService.shared.loadImage(for: beforePhoto, targetSize: targetSize),
                  let afterImage = PhotoStorageService.shared.loadImage(for: afterPhoto, targetSize: targetSize) else {
                DispatchQueue.main.async {
                    Haptics.warning()
                    showingShareError = true
                }
                return
            }

            let image = ShareComposerService.beforeAfterImage(
                before: beforeImage,
                after: afterImage,
                beforeLabel: beforeLabel,
                afterLabel: afterLabel,
                beforeDateText: beforeDateText,
                afterDateText: afterDateText,
                addWatermark: !isPro
            )

            DispatchQueue.main.async {
                Haptics.impact()
                shareItems = [image]
                showingShareSheet = true
            }
        }
    }
}
