import SwiftUI
import UIKit

struct FaceBlurPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    
    let originalImage: UIImage
    @State private var processedImage: UIImage
    @State private var showShareSheet = false
    
    let onShare: (UIImage) -> Void
    
    init(originalImage: UIImage, processedImage: UIImage, onShare: @escaping (UIImage) -> Void) {
        self.originalImage = originalImage
        self._processedImage = State(initialValue: processedImage)
        self.onShare = onShare
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ツールバー
                HStack {
                    Button("戻る") {
                        dismiss()
                    }
                    
                    Spacer()
                    
                    Text("顔ぼかし確認")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("共有") {
                        showShareSheet = true
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                // 画像プレビュー領域
                GeometryReader { geometry in
                    ZStack {
                        Color.black.ignoresSafeArea()
                        
                        Image(uiImage: processedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [processedImage])
        }
    }
}

#Preview {
    FaceBlurPreviewView(
        originalImage: UIImage(systemName: "photo") ?? UIImage(),
        processedImage: UIImage(systemName: "photo") ?? UIImage()
    ) { _ in }
}