import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            VStack {
                if let player = player {
                    VideoPlayer(player: player)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(video.dateRangeText)
                        .font(.headline)
                    
                    HStack {
                        Label("\(video.frameCount) " + "gallery.photos_count".localized, systemImage: "photo.stack")
                        Spacer()
                        Label(video.formattedDuration, systemImage: "timer")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: [video.fileURL]) {
                    showingShareSheet = false
                }
            }
            .onAppear {
                setupPlayer()
            }
            .onDisappear {
                player?.pause()
            }
        }
    }
    
    private func setupPlayer() {
        player = AVPlayer(url: video.fileURL)
        player?.play()
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { _ in
            player?.seek(to: .zero)
            player?.play()
        }
    }
}