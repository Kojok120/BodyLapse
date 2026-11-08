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
            
            // 体重・体脂肪率は写真と別の記録なので、写真を消しても残す
            
            NotificationCenter.default.post(name: Notification.Name("PhotosUpdated"), object: nil)
        } catch {
            videoAlertMessage = "calendar.delete_photo_failed".localized(with: error.localizedDescription)
            showingVideoAlert = true
        }
    }
    
    func copyPhoto(_ photo: Photo) {
        guard PhotoPasteboard.copy(photo) else { return }
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
        
        PhotoLibrarySaver.save(photos: [photo]) { result in
            switch result {
            case .success:
                self.showSaveSuccess(message: "gallery.photo_saved".localized)
            case .failure(let error):
                Haptics.error()
                self.videoAlertMessage = error.localizedDescription
                self.showingVideoAlert = true
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