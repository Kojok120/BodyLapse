import SwiftUI

class ComparisonViewModel: ObservableObject {
    @Published var photos: [Photo] = []
    @Published var firstPhoto: Photo?
    @Published var secondPhoto: Photo?
    @Published var showingFirstPhotoPicker = false
    @Published var showingSecondPhotoPicker = false
    
    init() {
        loadPhotos()
    }
    
    func loadPhotos() {
        photos = PhotoStorageService.shared.photos
        
        if firstPhoto == nil && photos.count > 0 {
            firstPhoto = photos.last
        }
        
        if secondPhoto == nil && photos.count > 0 {
            secondPhoto = photos.first
        }
    }
    
    func loadImage(for photo: Photo) -> UIImage? {
        PhotoStorageService.shared.loadImage(for: photo)
    }
}