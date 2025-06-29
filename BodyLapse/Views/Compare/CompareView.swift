import SwiftUI

struct CompareView: View {
    @StateObject private var viewModel = CompareViewModel()
    @StateObject private var userSettings = UserSettingsManager.shared
    @State private var firstPhoto: Photo?
    @State private var secondPhoto: Photo?
    @State private var showingFirstCalendar = false
    @State private var showingSecondCalendar = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Photo selection buttons
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
            .sheet(isPresented: $showingFirstCalendar) {
                CalendarPopupView(
                    selectedDate: Binding(
                        get: { firstPhoto?.captureDate ?? Date() },
                        set: { _ in }
                    ),
                    photos: viewModel.photos,
                    onDateSelected: { date in
                        // Reload photos to get latest weight/body fat data
                        print("[CompareView] Selecting first photo for date: \(date)")
                        viewModel.loadPhotos()
                        
                        // Wait a bit for weight sync to complete
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            firstPhoto = viewModel.photos.first { photo in
                                Calendar.current.isDate(photo.captureDate, inSameDayAs: date)
                            }
                            if let selected = firstPhoto {
                                print("[CompareView] Selected first photo - id: \(selected.id), weight: \(selected.weight ?? -1), bodyFat: \(selected.bodyFatPercentage ?? -1)")
                            } else {
                                print("[CompareView] No photo found for date: \(date)")
                            }
                        }
                        showingFirstCalendar = false
                    },
                    minDate: nil,
                    maxDate: secondPhoto?.captureDate
                )
            }
            .sheet(isPresented: $showingSecondCalendar) {
                CalendarPopupView(
                    selectedDate: Binding(
                        get: { secondPhoto?.captureDate ?? Date() },
                        set: { _ in }
                    ),
                    photos: viewModel.photos,
                    onDateSelected: { date in
                        // Reload photos to get latest weight/body fat data
                        print("[CompareView] Selecting second photo for date: \(date)")
                        viewModel.loadPhotos()
                        
                        // Wait a bit for weight sync to complete
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            secondPhoto = viewModel.photos.first { photo in
                                Calendar.current.isDate(photo.captureDate, inSameDayAs: date)
                            }
                            if let selected = secondPhoto {
                                print("[CompareView] Selected second photo - id: \(selected.id), weight: \(selected.weight ?? -1), bodyFat: \(selected.bodyFatPercentage ?? -1)")
                            } else {
                                print("[CompareView] No photo found for date: \(date)")
                            }
                        }
                        showingSecondCalendar = false
                    },
                    minDate: firstPhoto?.captureDate,
                    maxDate: nil
                )
            }
        }
        .onAppear {
            print("[ComparisonView] View appeared")
            viewModel.loadPhotos()
            // Load any photos with today's date
            let today = Date()
            secondPhoto = viewModel.photos.first { photo in
                Calendar.current.isDate(photo.captureDate, inSameDayAs: today)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Reload photos when app comes to foreground to get latest data
            viewModel.loadPhotos()
            // Update selected photos with fresh data
            if let first = firstPhoto {
                firstPhoto = viewModel.photos.first { $0.id == first.id }
            }
            if let second = secondPhoto {
                secondPhoto = viewModel.photos.first { $0.id == second.id }
            }
        }
    }
    
    private var comparisonView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Photos and weight/body fat section
                HStack(alignment: .top, spacing: 2) {
                    // First photo column
                    VStack(spacing: 0) {
                        // Photo container
                        Group {
                            if let photo = firstPhoto,
                               let image = PhotoStorageService.shared.loadImage(for: photo) {
                                ZStack {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: (UIScreen.main.bounds.width - 6) / 2, height: 250)
                                        .clipped()
                                        .overlay(
                                            VStack {
                                                HStack {
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text("compare.before".localized)
                                                            .font(.caption)
                                                            .fontWeight(.bold)
                                                        Text(formatDateShort(photo.captureDate))
                                                            .font(.caption2)
                                                    }
                                                    .padding(6)
                                                    .background(Color.black.opacity(0.7))
                                                    .foregroundColor(.white)
                                                    .cornerRadius(4)
                                                    .padding(8)
                                                    Spacer()
                                                }
                                                Spacer()
                                            }
                                        )
                                }
                            } else {
                                Rectangle()
                                    .fill(Color(UIColor.systemGray5))
                                    .frame(width: (UIScreen.main.bounds.width - 6) / 2, height: 250)
                                    .overlay(
                                        VStack {
                                            Image(systemName: "photo")
                                                .font(.system(size: 40))
                                                .foregroundColor(.gray)
                                            Text("compare.select_first".localized)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    )
                            }
                        }
                        .frame(height: 250)
                        
                        // Weight and body fat display for premium users
                        if userSettings.settings.isPremium {
                            VStack(spacing: 4) {
                                if let photo = firstPhoto {
                                    let _ = print("[CompareView] First photo - id: \(photo.id), date: \(photo.captureDate), weight: \(photo.weight ?? -1), bodyFat: \(photo.bodyFatPercentage ?? -1)")
                                    // Weight row
                                    HStack(spacing: 4) {
                                        Image(systemName: "scalemass")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                        if let weight = photo.weight {
                                            Text("\(convertedWeight(weight), specifier: "%.1f") \(userSettings.settings.weightUnit.symbol)")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.primary)
                                        } else {
                                            Text("compare.no_weight".localized)
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    // Body fat row
                                    if let bodyFat = photo.bodyFatPercentage {
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
                    }
                    
                    // Divider
                    Rectangle()
                        .fill(Color.bodyLapseLightGray)
                        .frame(width: 2)
                    
                    // Second photo column
                    VStack(spacing: 0) {
                        // Photo container
                        Group {
                            if let photo = secondPhoto,
                               let image = PhotoStorageService.shared.loadImage(for: photo) {
                                ZStack {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: (UIScreen.main.bounds.width - 6) / 2, height: 250)
                                        .clipped()
                                        .overlay(
                                            VStack {
                                                HStack {
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text("compare.after".localized)
                                                            .font(.caption)
                                                            .fontWeight(.bold)
                                                        Text(formatDateShort(photo.captureDate))
                                                            .font(.caption2)
                                                    }
                                                    .padding(6)
                                                    .background(Color.black.opacity(0.7))
                                                    .foregroundColor(.white)
                                                    .cornerRadius(4)
                                                    .padding(8)
                                                    Spacer()
                                                }
                                                Spacer()
                                            }
                                        )
                                }
                            } else {
                                Rectangle()
                                    .fill(Color(UIColor.systemGray5))
                                    .frame(width: (UIScreen.main.bounds.width - 6) / 2, height: 250)
                                    .overlay(
                                        VStack {
                                            Image(systemName: "photo")
                                                .font(.system(size: 40))
                                                .foregroundColor(.gray)
                                            Text("compare.select_second".localized)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    )
                            }
                        }
                        .frame(height: 250)
                        
                        // Weight and body fat display for premium users
                        if userSettings.settings.isPremium {
                            VStack(spacing: 4) {
                                if let photo = secondPhoto {
                                    let _ = print("[CompareView] Second photo - id: \(photo.id), date: \(photo.captureDate), weight: \(photo.weight ?? -1), bodyFat: \(photo.bodyFatPercentage ?? -1)")
                                    // Weight row
                                    HStack(spacing: 4) {
                                        Image(systemName: "scalemass")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                        if let weight = photo.weight {
                                            Text("\(convertedWeight(weight), specifier: "%.1f") \(userSettings.settings.weightUnit.symbol)")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.primary)
                                        } else {
                                            Text("compare.no_weight".localized)
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    // Body fat row
                                    if let bodyFat = photo.bodyFatPercentage {
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
                    }
                }
                .padding(.horizontal, 2)
                
                // Comparison stats
                if let first = firstPhoto, let second = secondPhoto {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Stats display
                            if userSettings.settings.isPremium {
                                HStack(spacing: 20) {
                                    // Weight difference
                                    if let weightDiff = viewModel.getWeightDifference(first, second) {
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
                                    
                                    // Body fat difference
                                    if let bodyFatDiff = viewModel.getBodyFatDifference(first, second) {
                                        if viewModel.getWeightDifference(first, second) != nil {
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
                            } else {
                                // Free user message
                                VStack(spacing: 8) {
                                    Image(systemName: "lock.fill")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                    Text("compare.upgrade_premium".localized)
                                        .font(.headline)
                                    Text("compare.premium_feature".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                    }
                }
                
                // Add extra space at bottom
                Spacer()
                    .frame(height: 100)
            }
            .padding(.bottom, 60) // Space for banner ad
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
                    
                    if let photo = firstPhoto {
                        Text(formatDate(photo.captureDate))
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
                    
                    if let photo = secondPhoto {
                        Text(formatDate(photo.captureDate))
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
        .padding(.top)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func convertedWeight(_ weight: Double) -> Double {
        userSettings.settings.weightUnit == .kg ? weight : weight * 2.20462
    }
}

