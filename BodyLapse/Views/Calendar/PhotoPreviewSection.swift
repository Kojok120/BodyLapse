import SwiftUI
import PhotosUI
import Photos
import UIKit

struct PhotoPreviewSection: View {
    let selectedDate: Date
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
            // Photo viewer
            if photosForSelectedDate.isEmpty {
                noPhotoPlaceholder
            } else if categoriesForSelectedDate.count > 1 {
                multipleCategoriesView
            } else {
                singleCategoryView
            }
            
            // Memo display - always show section
            memoSection
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
    
    /// 選択中の日付が「今日」のときだけ表示する、カメラ起動CTA。
    /// 過去日はカメラで撮影できないため、当日に限って案内する。
    @ViewBuilder
    private var takePhotoButton: some View {
        if Calendar.current.isDateInToday(selectedDate) {
            Button {
                Haptics.impact(.light)
                NotificationCenter.default.post(
                    name: Notification.Name("NavigateToCameraAndLaunch"),
                    object: nil
                )
            } label: {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("calendar.take_photo".localized)
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.bodyLapseTurquoise)
                .cornerRadius(20)
            }
            .accessibilityLabel("calendar.take_photo".localized)
        }
    }

    private var noPhotoPlaceholder: some View {
        GeometryReader { geometry in
            ZStack {
                // Placeholder image as background
                Image("placeholder-image")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .opacity(0.3)
                
                // Overlay content
                VStack {
                    Spacer()
                    
                    takePhotoButton

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
                    
                    Spacer()
                        .frame(height: 30)
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
                    if let photo = photosForSelectedDate.first(where: { $0.categoryId == categoryId }) {
                        StoredPhotoImageView(photo: photo, contentMode: .fit) {
                            categoryPlaceholder(categoryId: categoryId, geometry: geometry)
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .contextMenu {
                            photoContextMenu(photo: photo)
                        }
                        .overlay(alignment: .topTrailing) {
                            photoActionsButton(photo: photo)
                        }
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
            if let photo = currentPhoto {
                StoredPhotoImageView(photo: photo, contentMode: .fit) {
                    categoryPlaceholder(categoryId: viewModel.selectedCategory.id, geometry: geometry)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .contextMenu {
                    photoContextMenu(photo: photo)
                }
                .overlay(alignment: .topTrailing) {
                    photoActionsButton(photo: photo)
                }
            } else {
                categoryPlaceholder(categoryId: viewModel.selectedCategory.id, geometry: geometry)
            }
        }
        .frame(height: calculatePhotoHeight())
        .background(Color.black)
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func categoryPlaceholder(categoryId: String, geometry: GeometryProxy) -> some View {
        ZStack {
            // Placeholder image as background
            Image("placeholder-image")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .opacity(0.3)
            
            // Overlay content
            VStack {
                Spacer()
                
                takePhotoButton

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
                
                Spacer()
                    .frame(height: 30)
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
    }
    
    /// 長押しと同じ操作を、見えるボタンからも開けるようにする (長押しは知らないと見つからない)
    private func photoActionsButton(photo: Photo) -> some View {
        Menu {
            photoContextMenu(photo: photo)
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.system(size: 26))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.black.opacity(0.45))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("calendar.photo_actions".localized)
        .padding(4)
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
    
    
    private func calculatePhotoHeight() -> CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        let isSmallScreen = screenHeight < 700
        
        if isSmallScreen {
            return screenHeight * 0.28
        } else {
            return screenHeight * 0.38
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
