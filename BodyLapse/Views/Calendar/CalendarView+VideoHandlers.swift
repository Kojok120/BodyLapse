import SwiftUI
import Foundation

// MARK: - Video Generation Extension
extension CalendarView {
    
    func generateVideo(with options: VideoGenerationService.VideoGenerationOptions, startDate: Date, endDate: Date) {
        isGeneratingVideo = true
        videoGenerationProgress = 0
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        let dateRange = startOfDay...endOfDay
        
        VideoGenerationService.shared.generateVideo(
            from: viewModel.photos,
            in: dateRange,
            options: options,
            progress: { progress in
                DispatchQueue.main.async {
                    self.videoGenerationProgress = progress
                }
            },
            completion: { result in
                DispatchQueue.main.async {
                    self.isGeneratingVideo = false
                    self.videoGenerationProgress = 0
                    
                    switch result {
                    case .success(let video):
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NavigateToGalleryAndPlayVideo"),
                            object: nil,
                            userInfo: ["videoId": video.id]
                        )
                    case .failure(let error):
                        self.videoAlertMessage = error.localizedDescription
                        self.showingVideoAlert = true
                    }
                }
            }
        )
    }
}