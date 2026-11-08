import SwiftUI
import Photos

class GalleryActionService {
    static let shared = GalleryActionService()
    
    private init() {}
    
    // MARK: - 写真アクション
    
    func sharePhoto(_ photo: Photo, activeSheet: Binding<GalleryActiveSheet?>) {
        activeSheet.wrappedValue = .shareOptions(photo)
    }
    
    func handlePhotoShare(_ image: UIImage, activeSheet: Binding<GalleryActiveSheet?>) {
        activeSheet.wrappedValue = .share([image])
    }
    
    func savePhoto(_ photo: Photo, completion: @escaping (Result<Void, Error>) -> Void) {
        PhotoLibrarySaver.save(photos: [photo], completion: completion)
    }
    
    // MARK: - 動画アクション
    
    func shareVideo(_ video: Video, activeSheet: Binding<GalleryActiveSheet?>) {
        activeSheet.wrappedValue = .share([video.fileURL])
    }
    
    func saveVideo(_ video: Video, completion: @escaping (Result<Void, Error>) -> Void) {
        PhotoLibrarySaver.save(videos: [video], completion: completion)
    }
    
    // MARK: - 一括アクション
    
    /// 選んだ写真のファイル。画像を展開せずにファイルのまま共有する (枚数が多くてもメモリを抱えない)
    @MainActor
    func getSelectedPhotosForSharing(from viewModel: GalleryViewModel) -> [URL] {
        selectedPhotos(from: viewModel).compactMap { PhotoStorageService.shared.storedFileURL(for: $0) }
    }
    
    @MainActor
    func getSelectedVideosForSharing(from viewModel: GalleryViewModel) -> [URL] {
        return viewModel.selectedVideoIds.compactMap { videoId in
            guard let video = viewModel.videos.first(where: { $0.id.uuidString == videoId }) else { return nil }
            return video.fileURL
        }
    }
    
    @MainActor
    func bulkSavePhotosToLibrary(from viewModel: GalleryViewModel, completion: @escaping (Result<Void, Error>) -> Void) {
        PhotoLibrarySaver.save(photos: selectedPhotos(from: viewModel), completion: completion)
    }
    
    @MainActor
    func bulkSaveVideosToLibrary(from viewModel: GalleryViewModel, completion: @escaping (Result<Void, Error>) -> Void) {
        let selectedVideos = viewModel.selectedVideoIds.compactMap { videoId in
            viewModel.videos.first(where: { $0.id.uuidString == videoId })
        }
        PhotoLibrarySaver.save(videos: selectedVideos, completion: completion)
    }

    @MainActor
    private func selectedPhotos(from viewModel: GalleryViewModel) -> [Photo] {
        viewModel.selectedPhotoIds.compactMap { photoId in
            viewModel.photos.first(where: { $0.id.uuidString == photoId })
        }
    }
    
    // MARK: - ユーティリティメソッド
    
    func showSaveSuccess(message: String, showingSaveSuccess: Binding<Bool>, saveSuccessMessage: Binding<String>) {
        saveSuccessMessage.wrappedValue = message
        withAnimation {
            showingSaveSuccess.wrappedValue = true
        }
    }
}
// MARK: - 写真アプリへの保存

enum PhotoLibrarySaveError: LocalizedError {
    case accessDenied
    case nothingToSave
    case failed(Error?)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "photo_library.error.access_denied".localized
        case .nothingToSave:
            return "photo_library.error.nothing_to_save".localized
        case .failed(let error):
            if let error {
                return "photo_library.error.failed_with_reason".localized(with: error.localizedDescription)
            }
            return "photo_library.error.failed".localized
        }
    }
}

/// 写真アプリへ保存する。追加のみの権限で足りるので、ライブラリ全体の読み書きは求めない。
/// 写真はファイルのまま渡し、画像を展開しない。完了はメインスレッドで返す。
enum PhotoLibrarySaver {
    static func save(photos: [Photo] = [], videos: [Video] = [], completion: @escaping (Result<Void, Error>) -> Void) {
        let photoURLs = photos.compactMap { PhotoStorageService.shared.storedFileURL(for: $0) }
        let videoURLs = videos.map(\.fileURL).filter { FileManager.default.fileExists(atPath: $0.path) }
        func finish(_ result: Result<Void, Error>) {
            DispatchQueue.main.async { completion(result) }
        }
        guard !photoURLs.isEmpty || !videoURLs.isEmpty else {
            finish(.failure(PhotoLibrarySaveError.nothingToSave))
            return
        }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                finish(.failure(PhotoLibrarySaveError.accessDenied))
                return
            }
            PHPhotoLibrary.shared().performChanges({
                for url in photoURLs {
                    PHAssetCreationRequest.forAsset().addResource(with: .photo, fileURL: url, options: nil)
                }
                for url in videoURLs {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }
            }) { success, error in
                finish(success ? .success(()) : .failure(PhotoLibrarySaveError.failed(error)))
            }
        }
    }
}
