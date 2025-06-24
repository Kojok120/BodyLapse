import SwiftUI

struct CompareView: View {
    @StateObject private var viewModel = CompareViewModel()
    @State private var firstPhoto: Photo?
    @State private var secondPhoto: Photo?
    @State private var showingFirstPhotoPicker = false
    @State private var showingSecondPhotoPicker = false
    
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
            .sheet(isPresented: $showingFirstPhotoPicker) {
                ComparePhotoPickerView(selectedPhoto: $firstPhoto, excludePhoto: secondPhoto)
            }
            .sheet(isPresented: $showingSecondPhotoPicker) {
                ComparePhotoPickerView(selectedPhoto: $secondPhoto, excludePhoto: firstPhoto)
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
                                    Text(photo.formattedDate)
                                        .font(.caption)
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
                                    Text(photo.formattedDate)
                                        .font(.caption)
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
                
                // Comparison slider
                if firstPhoto != nil && secondPhoto != nil {
                    ComparisonSlider(
                        firstPhoto: firstPhoto!,
                        secondPhoto: secondPhoto!,
                        width: geometry.size.width
                    )
                    .frame(height: 60)
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
                showingFirstPhotoPicker = true
            }) {
                HStack {
                    Image(systemName: "1.circle.fill")
                    Text("First Photo")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
            }
            
            Button(action: {
                showingSecondPhotoPicker = true
            }) {
                HStack {
                    Image(systemName: "2.circle.fill")
                    Text("Second Photo")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
            }
        }
        .padding()
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

struct ComparePhotoPickerView: View {
    @Binding var selectedPhoto: Photo?
    let excludePhoto: Photo?
    @Environment(\.dismiss) private var dismiss
    @State private var photos: [Photo] = []
    
    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(photos) { photo in
                        if excludePhoto?.id != photo.id {
                            PhotoThumbnail(photo: photo) {
                                selectedPhoto = photo
                                dismiss()
                            }
                        }
                    }
                }
                .padding(2)
            }
            .navigationTitle("Select Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                photos = PhotoStorageService.shared.photos.sorted { $0.captureDate > $1.captureDate }
            }
        }
    }
}

struct PhotoThumbnail: View {
    let photo: Photo
    let onTap: () -> Void
    @State private var image: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            GeometryReader { geometry in
                ZStack {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.width)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color(UIColor.systemGray5))
                            .overlay(ProgressView())
                    }
                    
                    VStack {
                        Spacer()
                        HStack {
                            Text(formatDate(photo.captureDate))
                                .font(.caption2)
                                .padding(4)
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                            Spacer()
                        }
                        .padding(4)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedImage = PhotoStorageService.shared.loadImage(for: photo)
            DispatchQueue.main.async {
                self.image = loadedImage
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}