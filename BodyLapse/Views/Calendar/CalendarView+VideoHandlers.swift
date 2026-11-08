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
                    case .success(let outcome):
                        Haptics.success()
                        if outcome.framesWithoutDetectedFaces > 0 {
                            // 顔が見つからずぼかしていないコマがある。確かめてもらってからギャラリーへ
                            self.pendingVideoIdToPlay = outcome.video.id
                            self.videoAlertMessage = "face_blur.video_frames_without_faces".localized(with: outcome.framesWithoutDetectedFaces)
                            self.showingVideoAlert = true
                        } else {
                            self.openGeneratedVideo(outcome.video.id)
                        }
                    case .failure(let error):
                        Haptics.error()
                        self.videoAlertMessage = error.localizedDescription
                        self.showingVideoAlert = true
                    }
                }
            }
        )
    }

    func openGeneratedVideo(_ videoId: UUID) {
        NotificationCenter.default.post(
            name: NSNotification.Name("NavigateToGalleryAndPlayVideo"),
            object: nil,
            userInfo: ["videoId": videoId]
        )
    }
}