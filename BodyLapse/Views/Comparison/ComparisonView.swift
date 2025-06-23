import SwiftUI

struct ComparisonView: View {
    @StateObject private var viewModel = ComparisonViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.photos.count >= 2 {
                    VStack {
                        ComparisonControlsView(
                            firstDate: viewModel.firstPhoto?.captureDate ?? Date(),
                            secondDate: viewModel.secondPhoto?.captureDate ?? Date(),
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
                PhotoPickerView(photos: viewModel.photos) { photo in
                    viewModel.firstPhoto = photo
                    viewModel.showingFirstPhotoPicker = false
                }
            }
            .sheet(isPresented: $viewModel.showingSecondPhotoPicker) {
                PhotoPickerView(photos: viewModel.photos) { photo in
                    viewModel.secondPhoto = photo
                    viewModel.showingSecondPhotoPicker = false
                }
            }
        }
        .onAppear {
            viewModel.loadPhotos()
        }
    }
}

struct ComparisonControlsView: View {
    let firstDate: Date
    let secondDate: Date
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
                VStack {
                    Text("Before")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(dateFormatter.string(from: firstDate))
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
            }
            
            Image(systemName: "arrow.right")
                .foregroundColor(.secondary)
            
            Button(action: onSecondDateTap) {
                VStack {
                    Text("After")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(dateFormatter.string(from: secondDate))
                        .font(.headline)
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

struct PhotoPickerView: View {
    let photos: [Photo]
    let onSelection: (Photo) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(photos) { photo in
                        PhotoPickerItemView(photo: photo) {
                            onSelection(photo)
                        }
                    }
                }
                .padding()
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
        }
    }
}

struct PhotoPickerItemView: View {
    let photo: Photo
    let onTap: () -> Void
    @State private var image: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .aspectRatio(1, contentMode: .fit)
                
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    ProgressView()
                }
                
                VStack {
                    Spacer()
                    Text(photo.captureDate, style: .date)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(5)
                        .padding(5)
                }
            }
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
}