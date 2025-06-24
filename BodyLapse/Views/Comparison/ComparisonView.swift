import SwiftUI

struct ComparisonView: View {
    @StateObject private var viewModel = ComparisonViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.photos.count >= 2 {
                    VStack {
                        ComparisonControlsView(
                            firstPhoto: viewModel.firstPhoto,
                            secondPhoto: viewModel.secondPhoto,
                            onFirstDateTap: { viewModel.showingFirstPhotoPicker = true },
                            onSecondDateTap: { viewModel.showingSecondPhotoPicker = true }
                        )
                        .padding()
                        
                        GeometryReader { geometry in
                            HStack(spacing: 2) {
                                if let firstPhoto = viewModel.firstPhoto,
                                   let firstImage = viewModel.loadImage(for: firstPhoto) {
                                    Image(uiImage: firstImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: geometry.size.width / 2 - 1)
                                } else {
                                    EmptyPhotoView(text: "Select first photo")
                                        .frame(width: geometry.size.width / 2 - 1)
                                }
                                
                                if let secondPhoto = viewModel.secondPhoto,
                                   let secondImage = viewModel.loadImage(for: secondPhoto) {
                                    Image(uiImage: secondImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: geometry.size.width / 2 - 1)
                                } else {
                                    EmptyPhotoView(text: "Select second photo")
                                        .frame(width: geometry.size.width / 2 - 1)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Not enough photos")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Take at least 2 photos to start comparing your progress")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Compare Progress")
            .sheet(isPresented: $viewModel.showingFirstPhotoPicker) {
                CalendarPopupView(
                    selectedDate: Binding(
                        get: { viewModel.firstPhoto?.captureDate ?? Date() },
                        set: { _ in }
                    ),
                    photos: viewModel.photos,
                    onDateSelected: { date in
                        viewModel.firstPhoto = viewModel.photos.first { photo in
                            Calendar.current.isDate(photo.captureDate, inSameDayAs: date)
                        }
                        viewModel.showingFirstPhotoPicker = false
                    }
                )
            }
            .sheet(isPresented: $viewModel.showingSecondPhotoPicker) {
                CalendarPopupView(
                    selectedDate: Binding(
                        get: { viewModel.secondPhoto?.captureDate ?? Date() },
                        set: { _ in }
                    ),
                    photos: viewModel.photos,
                    onDateSelected: { date in
                        viewModel.secondPhoto = viewModel.photos.first { photo in
                            Calendar.current.isDate(photo.captureDate, inSameDayAs: date)
                        }
                        viewModel.showingSecondPhotoPicker = false
                    }
                )
            }
        }
        .onAppear {
            viewModel.loadPhotos()
        }
    }
}

struct ComparisonControlsView: View {
    let firstPhoto: Photo?
    let secondPhoto: Photo?
    let onFirstDateTap: () -> Void
    let onSecondDateTap: () -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    var body: some View {
        HStack(spacing: 20) {
            Button(action: onFirstDateTap) {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "calendar")
                        Text("Before")
                    }
                    .font(.headline)
                    .foregroundColor(.primary)
                    
                    if let photo = firstPhoto {
                        Text(dateFormatter.string(from: photo.captureDate))
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
            
            Image(systemName: "arrow.right")
                .foregroundColor(.secondary)
            
            Button(action: onSecondDateTap) {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "calendar")
                        Text("After")
                    }
                    .font(.headline)
                    .foregroundColor(.primary)
                    
                    if let photo = secondPhoto {
                        Text(dateFormatter.string(from: photo.captureDate))
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
    }
}

struct EmptyPhotoView: View {
    let text: String
    
    var body: some View {
        VStack {
            Image(systemName: "photo")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
    }
}

