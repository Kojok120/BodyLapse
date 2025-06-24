import SwiftUI

struct CompareView: View {
    @StateObject private var viewModel = CompareViewModel()
    @State private var firstPhoto: Photo?
    @State private var secondPhoto: Photo?
    @State private var showingFirstCalendar = false
    @State private var showingSecondCalendar = false
    @State private var firstSelectedDate = Date()
    @State private var secondSelectedDate = Date()
    
    var body: some View {
        NavigationView {
            VStack {
                if firstPhoto != nil || secondPhoto != nil {
                    comparisonView
                } else {
                    emptyStateView
                }
                
                photoSelectionButtons
            }
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.loadPhotos()
            }
            .sheet(isPresented: $showingFirstCalendar) {
                CalendarPopupView(
                    selectedDate: $firstSelectedDate,
                    photos: viewModel.photos,
                    onDateSelected: { date in
                        firstSelectedDate = date
                        firstPhoto = viewModel.photos.first { photo in
                            Calendar.current.isDate(photo.captureDate, inSameDayAs: date)
                        }
                        showingFirstCalendar = false
                    }
                )
            }
            .sheet(isPresented: $showingSecondCalendar) {
                CalendarPopupView(
                    selectedDate: $secondSelectedDate,
                    photos: viewModel.photos,
                    onDateSelected: { date in
                        secondSelectedDate = date
                        secondPhoto = viewModel.photos.first { photo in
                            Calendar.current.isDate(photo.captureDate, inSameDayAs: date)
                        }
                        showingSecondCalendar = false
                    }
                )
            }
        }
    }
    
    private var comparisonView: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // First photo
                    ZStack {
                        if let photo = firstPhoto,
                           let image = PhotoStorageService.shared.loadImage(for: photo) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geometry.size.width / 2)
                        } else {
                            Rectangle()
                                .fill(Color(UIColor.systemGray5))
                                .frame(width: geometry.size.width / 2)
                                .overlay(
                                    VStack {
                                        Image(systemName: "photo")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                        Text("Select First Photo")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                )
                        }
                        
                        VStack {
                            HStack {
                                if let photo = firstPhoto {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Before")
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
                                }
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                    
                    // Divider
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2)
                    
                    // Second photo
                    ZStack {
                        if let photo = secondPhoto,
                           let image = PhotoStorageService.shared.loadImage(for: photo) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geometry.size.width / 2)
                        } else {
                            Rectangle()
                                .fill(Color(UIColor.systemGray5))
                                .frame(width: geometry.size.width / 2)
                                .overlay(
                                    VStack {
                                        Image(systemName: "photo")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                        Text("Select Second Photo")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                )
                        }
                        
                        VStack {
                            HStack {
                                if let photo = secondPhoto {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("After")
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
                                }
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                }
                
                // Comparison stats and slider
                if let first = firstPhoto, let second = secondPhoto {
                    VStack(spacing: 16) {
                        // Stats display
                        HStack(spacing: 20) {
                            // Days between
                            VStack(spacing: 4) {
                                Text("\(viewModel.getDaysBetween(first, second))")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("days")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                                .frame(height: 30)
                            
                            // Weight difference
                            if let weightDiff = viewModel.getWeightDifference(first, second) {
                                VStack(spacing: 4) {
                                    HStack(spacing: 2) {
                                        Image(systemName: weightDiff > 0 ? "arrow.up" : "arrow.down")
                                            .font(.caption)
                                        Text("\(abs(weightDiff), specifier: "%.1f") kg")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(weightDiff > 0 ? .red : .green)
                                    Text("weight")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Body fat difference
                            if let bodyFatDiff = viewModel.getBodyFatDifference(first, second) {
                                Divider()
                                    .frame(height: 30)
                                
                                VStack(spacing: 4) {
                                    HStack(spacing: 2) {
                                        Image(systemName: bodyFatDiff > 0 ? "arrow.up" : "arrow.down")
                                            .font(.caption)
                                        Text("\(abs(bodyFatDiff), specifier: "%.1f")%")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(bodyFatDiff > 0 ? .red : .green)
                                    Text("body fat")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(10)
                        
                        ComparisonSlider(
                            firstPhoto: first,
                            secondPhoto: second,
                            width: geometry.size.width
                        )
                        .frame(height: 60)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("Compare Your Progress")
                .font(.headline)
                .foregroundColor(.primary)
            Text("Select two photos to see your transformation")
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
                        Text("Before")
                    }
                    .font(.headline)
                    
                    if let photo = firstPhoto {
                        Text(formatDate(photo.captureDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Select Date")
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
                        Text("After")
                    }
                    .font(.headline)
                    
                    if let photo = secondPhoto {
                        Text(formatDate(photo.captureDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Select Date")
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
        .padding()
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
}

struct ComparisonSlider: View {
    let firstPhoto: Photo
    let secondPhoto: Photo
    let width: CGFloat
    
    @State private var sliderPosition: CGFloat = 0.5
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(UIColor.systemGray5))
                    .frame(height: 4)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                // Slider handle
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 20, height: 20)
                    .position(x: sliderPosition * geometry.size.width, y: geometry.size.height / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                sliderPosition = max(0, min(1, value.location.x / geometry.size.width))
                            }
                    )
            }
        }
    }
}

