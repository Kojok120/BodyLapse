import Foundation
import SwiftUI

class GalleryViewModel: ObservableObject {
    @Published var photos: [Photo] = []
    @Published var videos: [Video] = []
    @Published var selectedSection: GallerySection = .videos
    
    enum GallerySection: String, CaseIterable {
        case videos = "Videos"
        case photos = "Photos"
    }
    
    init() {
        loadData()
    }
    
    func loadData() {
        loadPhotos()
        loadVideos()
    }
    
    func loadPhotos() {
        photos = PhotoStorageService.shared.photos
    }
    
    func loadVideos() {
        VideoStorageService.shared.initialize()
        videos = VideoStorageService.shared.videos
    }
    
    func deletePhoto(_ photo: Photo) {
        do {
            try PhotoStorageService.shared.deletePhoto(photo)
            loadPhotos()
        } catch {
            print("Failed to delete photo: \(error)")
        }
    }
    
    func deleteVideo(_ video: Video) {
        do {
            try VideoStorageService.shared.deleteVideo(video)
            loadVideos()
        } catch {
            print("Failed to delete video: \(error)")
        }
    }
    
    func photosGroupedByMonth() -> [(String, [Photo])] {
        let grouped = Dictionary(grouping: photos) { photo in
            formatMonthYear(from: photo.captureDate)
        }
        
        return grouped.sorted { lhs, rhs in
            guard let lhsDate = dateFromMonthYear(lhs.key),
                  let rhsDate = dateFromMonthYear(rhs.key) else {
                return false
            }
            return lhsDate > rhsDate
        }
    }
    
    func videosGroupedByMonth() -> [(String, [Video])] {
        let grouped = Dictionary(grouping: videos) { video in
            formatMonthYear(from: video.createdDate)
        }
        
        return grouped.sorted { lhs, rhs in
            guard let lhsDate = dateFromMonthYear(lhs.key),
                  let rhsDate = dateFromMonthYear(rhs.key) else {
                return false
            }
            return lhsDate > rhsDate
        }
    }
    
    private func formatMonthYear(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func dateFromMonthYear(_ monthYear: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.date(from: monthYear)
    }
}