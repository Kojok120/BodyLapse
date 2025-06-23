import SwiftUI

struct PhotoReviewView: View {
    let image: UIImage
    let onSave: (UIImage) -> Void
    let onCancel: () -> Void
    
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            VStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .overlay(
                        Group {
                            if isProcessing {
                                Color.black.opacity(0.5)
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                            }
                        }
                    )
                
                Spacer()
            }
            .navigationTitle("Review Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .disabled(isProcessing)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        isProcessing = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onSave(image)
                        }
                    }
                    .disabled(isProcessing)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}