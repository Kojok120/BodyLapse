import SwiftUI
import Photos
import PhotosUI

// MARK: - Photo Handling Extension
extension CalendarView {
    
    func deletePhoto(_ photo: Photo) {
        do {
            try PhotoStorageService.shared.deletePhoto(photo)
            viewModel.loadPhotos()
            viewModel.loadCategories()
            updateCurrentPhoto()
            
            if photo.weight != nil || photo.bodyFatPercentage != nil {
                Task {
                    let remainingPhotosForDate = PhotoStorageService.shared.getPhotosForDate(photo.captureDate)
                    
                    if remainingPhotosForDate.isEmpty {
                        if let existingEntry = try await WeightStorageService.shared.getEntry(for: photo.captureDate) {
                            try await WeightStorageService.shared.deleteEntry(existingEntry)
                        }
                    }
                    
                    await MainActor.run {
                        weightViewModel.loadEntries()
                    }
                }
            }
            
            NotificationCenter.default.post(name: Notification.Name("PhotosUpdated"), object: nil)
        } catch {
            videoAlertMessage = "Failed to delete photo: \(error.localizedDescription)"
            showingVideoAlert = true
        }
    }
    
    func copyPhoto(_ photo: Photo) {
        guard let image = PhotoStorageService.shared.loadImage(for: photo) else { return }
        UIPasteboard.general.image = image
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func sharePhoto(_ photo: Photo) {
        activeSheet = .shareOptions(photo)
    }
    
    func handlePhotoShare(_ image: UIImage, withFaceBlur: Bool) {
        itemToShare = [image]
        activeSheet = .share([image])
    }
    
    func savePhoto(_ photo: Photo) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    self.videoAlertMessage = "gallery.photo_library_access_denied".localized
                    self.showingVideoAlert = true
                }
                return
            }
            
            guard let image = PhotoStorageService.shared.loadImage(for: photo) else {
                DispatchQueue.main.async {
                    self.videoAlertMessage = "Failed to load image"
                    self.showingVideoAlert = true
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.showSaveSuccess(message: "gallery.photo_saved".localized)
                    } else {
                        self.videoAlertMessage = error?.localizedDescription ?? "Failed to save photo"
                        self.showingVideoAlert = true
                    }
                }
            }
        }
    }
    
    func showSaveSuccess(message: String) {
        saveSuccessMessage = message
        withAnimation {
            showingSaveSuccess = true
        }
    }
    
    func handlePhotoImport(categoryId: String, photoItems: [PhotosPickerItem]) {
        Task {
            do {
                guard let item = photoItems.first,
                      let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    throw NSError(domain: "PhotoImport", code: 1, userInfo: [NSLocalizedDescriptionKey: "calendar.invalid_image".localized])
                }
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dateString = dateFormatter.string(from: selectedDate)
                if PhotoStorageService.shared.photoExists(for: dateString, categoryId: categoryId) {
                    throw NSError(domain: "PhotoImport", code: 2, userInfo: [NSLocalizedDescriptionKey: "calendar.photo_already_exists".localized])
                }
                
                let photo = try PhotoStorageService.shared.savePhoto(
                    image,
                    captureDate: selectedDate,
                    categoryId: categoryId,
                    weight: nil,
                    bodyFatPercentage: nil
                )
                
                await MainActor.run {
                    viewModel.loadPhotos()
                    viewModel.loadCategories()
                    updateCurrentPhoto()
                    showSaveSuccess(message: "calendar.photo_imported".localized)
                }
            } catch {
                await MainActor.run {
                    videoAlertMessage = error.localizedDescription
                    showingVideoAlert = true
                }
            }
        }
    }
}