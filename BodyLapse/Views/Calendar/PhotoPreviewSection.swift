import SwiftUI
import PhotosUI
import Photos

struct PhotoPreviewSection: View {
    let selectedDate: Date
    let isPremium: Bool
    @Binding var currentPhoto: Photo?
    @Binding var currentMemo: String
    @Binding var showingMemoEditor: Bool
    @Binding var currentCategoryIndex: Int
    let photosForSelectedDate: [Photo]
    let categoriesForSelectedDate: [PhotoCategory]
    let viewModel: CalendarViewModel
    let onCategorySwitch: (Int) -> Void
    let onPhotoDelete: (Photo) -> Void
    let onPhotoShare: (Photo) -> Void
    let onPhotoCopy: (Photo) -> Void
    let onPhotoSave: (Photo) -> Void
    let onPhotoImport: (String, [PhotosPickerItem]) -> Void
    
    @State private var showingDeleteAlert = false
    @State private var photoToDelete: Photo?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var importCategoryId: String?
    
    var body: some View {
        VStack(spacing: 8) {
            // Date display - only for free users
            if !isPremium {
                Text(formatDate(selectedDate))
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.top, 8)
            }
            
            // Memo display - always show section
            memoSection
            
            // Photo viewer
            if photosForSelectedDate.isEmpty {
                noPhotoPlaceholder
            } else if categoriesForSelectedDate.count > 1 {
                multipleCategoriesView
            } else {
                singleCategoryView
            }
        }
        .padding(.horizontal)
        .alert("calendar.confirm_delete_photo".localized, isPresented: $showingDeleteAlert) {
            Button("common.cancel".localized, role: .cancel) { }
            Button("common.delete".localized, role: .destructive) {
                if let photo = photoToDelete {
                    onPhotoDelete(photo)
                }
            }
        } message: {
            Text("calendar.delete_photo_message".localized)
        }
    }
    
    private var memoSection: some View {
        HStack {
            Image(systemName: currentMemo.isEmpty ? "note.text.badge.plus" : "note.text")
                .font(.caption)
                .foregroundColor(currentMemo.isEmpty ? .secondary : .bodyLapseTurquoise)
            
            if currentMemo.isEmpty {
                Text("calendar.add_memo".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text(currentMemo)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
        .onTapGesture {
            showingMemoEditor = true
        }
    }
    
    private var noPhotoPlaceholder: some View {
        GeometryReader { geometry in
            VStack(spacing: 20) {
                Image(systemName: "photo")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                Text("calendar.no_photo".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 1,
                    matching: .images
                ) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("calendar.upload_photo".localized)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.bodyLapseTurquoise)
                    .cornerRadius(20)
                }
                .onChange(of: selectedPhotoItems) { _, items in
                    if !items.isEmpty {
                        importCategoryId = viewModel.selectedCategory.id
                        handlePhotoImport()
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(height: calculatePhotoHeight())
    }
    
    private var multipleCategoriesView: some View {
        TabView(selection: $currentCategoryIndex) {
            ForEach(0..<categoriesForSelectedDate.count, id: \.self) { index in
                GeometryReader { geometry in
                    let categoryId = categoriesForSelectedDate[index].id
                    if let photo = photosForSelectedDate.first(where: { $0.categoryId == categoryId }),
                       let uiImage = PhotoStorageService.shared.loadImage(for: photo) {
                        photoImage(uiImage: uiImage, photo: photo, geometry: geometry)
                            .tag(index)
                    } else {
                        categoryPlaceholder(categoryId: categoriesForSelectedDate[index].id, geometry: geometry)
                            .tag(index)
                    }
                }
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .frame(height: calculatePhotoHeight())
        .background(Color.black)
        .cornerRadius(12)
        .onChange(of: currentCategoryIndex) { _, newIndex in
            // Haptic feedback when page changes
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            // Update the current photo
            if newIndex < categoriesForSelectedDate.count {
                onCategorySwitch(newIndex)
            }
        }
    }
    
    private var singleCategoryView: some View {
        GeometryReader { geometry in
            if let photo = currentPhoto,
               let uiImage = PhotoStorageService.shared.loadImage(for: photo) {
                photoImage(uiImage: uiImage, photo: photo, geometry: geometry)
            } else {
                categoryPlaceholder(categoryId: viewModel.selectedCategory.id, geometry: geometry)
            }
        }
        .frame(height: calculatePhotoHeight())
        .background(Color.black)
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func photoImage(uiImage: UIImage, photo: Photo, geometry: GeometryProxy) -> some View {
        Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contextMenu {
                photoContextMenu(photo: photo)
            }
    }
    
    @ViewBuilder
    private func categoryPlaceholder(categoryId: String, geometry: GeometryProxy) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "photo")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("calendar.no_photo".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 1,
                matching: .images
            ) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("calendar.upload_photo".localized)
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.bodyLapseTurquoise)
                .cornerRadius(20)
            }
            .onChange(of: selectedPhotoItems) { _, items in
                if !items.isEmpty {
                    importCategoryId = categoryId
                    handlePhotoImport()
                }
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
    }
    
    @ViewBuilder
    private func photoContextMenu(photo: Photo) -> some View {
        Button {
            onPhotoCopy(photo)
        } label: {
            Label("common.copy".localized, systemImage: "doc.on.doc")
        }
        
        Button {
            onPhotoShare(photo)
        } label: {
            Label("common.share".localized, systemImage: "square.and.arrow.up")
        }
        
        Button {
            onPhotoSave(photo)
        } label: {
            Label("gallery.save_to_photos".localized, systemImage: "square.and.arrow.down")
        }
        
        Divider()
        
        Button(role: .destructive) {
            photoToDelete = photo
            showingDeleteAlert = true
        } label: {
            Label("common.delete".localized, systemImage: "trash")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        // Check current language and set appropriate format
        let currentLanguage = LanguageManager.shared.currentLanguage
        switch currentLanguage {
        case "ja":
            formatter.dateFormat = "yyyy/MM/dd"
        case "ko":
            formatter.dateFormat = "yyyy.MM.dd"
        default:
            formatter.dateFormat = "MMM d, yyyy"
        }
        
        return formatter.string(from: date)
    }
    
    private func calculatePhotoHeight() -> CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        let isSmallScreen = screenHeight < 700
        
        if isSmallScreen {
            return isPremium ? screenHeight * 0.28 : screenHeight * 0.35
        } else {
            return isPremium ? screenHeight * 0.38 : screenHeight * 0.46
        }
    }
    
    private func handlePhotoImport() {
        if let categoryId = importCategoryId {
            onPhotoImport(categoryId, selectedPhotoItems)
            // Clear selection immediately
            selectedPhotoItems = []
            importCategoryId = nil
        }
    }
}