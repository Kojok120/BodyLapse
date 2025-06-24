import SwiftUI

struct ContourConfirmationView: View {
    let image: UIImage
    let contour: [CGPoint]
    let onConfirm: () -> Void
    let onRetry: () -> Void
    
    @State private var showingContourPreview = true
    
    var body: some View {
        ZStack {
            // Background
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                // Title
                Text("Confirm Body Outline")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 50)
                
                Text("Is the green outline correctly following your body?")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Image with contour overlay
                GeometryReader { geometry in
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                        
                        if showingContourPreview {
                            ContourOverlay(
                                contour: contour,
                                imageSize: image.size,
                                viewSize: geometry.size
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding()
                
                // Toggle to show/hide contour
                Toggle("Show Outline", isOn: $showingContourPreview)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .padding(.horizontal, 40)
                    .foregroundColor(.white)
                
                // Action buttons
                HStack(spacing: 20) {
                    Button(action: onRetry) {
                        Text("Retake")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: onConfirm) {
                        Text("Confirm")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}

struct ContourOverlay: View {
    let contour: [CGPoint]
    let imageSize: CGSize
    let viewSize: CGSize
    
    private var scaledContour: [CGPoint] {
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height
        
        var scale: CGFloat
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0
        
        if imageAspect > viewAspect {
            // Image is wider, fit to width
            scale = viewSize.width / imageSize.width
            let scaledHeight = imageSize.height * scale
            offsetY = (viewSize.height - scaledHeight) / 2
        } else {
            // Image is taller, fit to height
            scale = viewSize.height / imageSize.height
            let scaledWidth = imageSize.width * scale
            offsetX = (viewSize.width - scaledWidth) / 2
        }
        
        return contour.map { point in
            CGPoint(
                x: point.x * scale + offsetX,
                y: point.y * scale + offsetY
            )
        }
    }
    
    var body: some View {
        Path { path in
            guard scaledContour.count > 2 else { return }
            
            path.move(to: scaledContour[0])
            for i in 1..<scaledContour.count {
                path.addLine(to: scaledContour[i])
            }
            path.closeSubpath()
        }
        .stroke(Color.green, lineWidth: 3)
        .shadow(color: .black, radius: 2)
    }
}