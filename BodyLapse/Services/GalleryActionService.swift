import SwiftUI
import Photos

class GalleryActionService {
    static let shared = GalleryActionService()
    
    private init() {}
    
    // MARK: - Photo Actions
    
    func sharePhoto(_ photo: Photo, activeSheet: Binding<GalleryActiveSheet?>) {
        activeSheet.wrappedValue = .shareOptions(photo)
    }
    
    func handlePhotoShare(_ image: UIImage, withFaceBlur: Bool, activeSheet: Binding<GalleryActiveSheet?>) {
        activeSheet.wrappedValue = .share([image])
    }
    
    func savePhoto(_ photo: Photo, completion: @escaping (Bool, Error?) -> Void) {
        guard let image = PhotoStorageService.shared.loadImage(for: photo) else {
            completion(false, NSError(domain: "GalleryActionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"]))
            return
        }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }, completionHandler: completion)
    }
    
    // MARK: - Video Actions
    
    func shareVideo(_ video: Video, activeSheet: Binding<GalleryActiveSheet?>) {
        activeSheet.wrappedValue = .share([video.fileURL])
    }
    
    func saveVideo(_ video: Video, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: video.fileURL)
        }, completionHandler: completion)
    }
    
    // MARK: - Bulk Actions
    
    @MainActor
    func getSelectedPhotosForSharing(from viewModel: GalleryViewModel) -> [UIImage] {
        return viewModel.selectedPhotoIds.compactMap { photoId in
            guard let photo = viewModel.photos.first(where: { $0.id.uuidString == photoId }) else { return nil }
            return PhotoStorageService.shared.loadImage(for: photo)
        }
    }
    
    @MainActor
    func getSelectedVideosForSharing(from viewModel: GalleryViewModel) -> [URL] {
        return viewModel.selectedVideoIds.compactMap { videoId in
            guard let video = viewModel.videos.first(where: { $0.id.uuidString == videoId }) else { return nil }
            return video.fileURL
        }
    }
    
    @MainActor
    func bulkSavePhotosToLibrary(from viewModel: GalleryViewModel, completion: @escaping (Bool, Error?) -> Void) {
        let selectedPhotos = viewModel.selectedPhotoIds.compactMap { photoId in
            viewModel.photos.first(where: { $0.id.uuidString == photoId })
        }
        
        let images = selectedPhotos.compactMap { PhotoStorageService.shared.loadImage(for: $0) }
        
        guard !images.isEmpty else {
            completion(false, NSError(domain: "GalleryActionService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No images to save"]))
            return
        }
        
        PHPhotoLibrary.shared().performChanges({
            for image in images {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        }, completionHandler: completion)
    }
    
    @MainActor
    func bulkSaveVideosToLibrary(from viewModel: GalleryViewModel, completion: @escaping (Bool, Error?) -> Void) {
        let selectedVideos = viewModel.selectedVideoIds.compactMap { videoId in
            viewModel.videos.first(where: { $0.id.uuidString == videoId })
        }
        
        guard !selectedVideos.isEmpty else {
            completion(false, NSError(domain: "GalleryActionService", code: 3, userInfo: [NSLocalizedDescriptionKey: "No videos to save"]))
            return
        }
        
        PHPhotoLibrary.shared().performChanges({
            for video in selectedVideos {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: video.fileURL)
            }
        }, completionHandler: completion)
    }
    
    // MARK: - Utility Methods
    
    func showSaveSuccess(message: String, showingSaveSuccess: Binding<Bool>, saveSuccessMessage: Binding<String>) {
        saveSuccessMessage.wrappedValue = message
        withAnimation {
            showingSaveSuccess.wrappedValue = true
        }
    }
}