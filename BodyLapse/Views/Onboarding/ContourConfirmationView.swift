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
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                        
                        if showingContourPreview {
                            ContourOverlay(
                                contour: contour,
                                imageSize: image.size,
                                viewSize: geometry.size
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(12)
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
                        Text("confirm.retake".localized)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: onConfirm) {
                        Text("confirm.confirm".localized)
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
        // Use aspect fill logic to match camera preview
        let scaleX = viewSize.width / imageSize.width
        let scaleY = viewSize.height / imageSize.height
        // Use the larger scale to ensure the view is filled
        let scale = max(scaleX, scaleY)
        
        // Calculate the size after scaling
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        
        // Calculate offset to center the scaled content
        let offsetX = (viewSize.width - scaledWidth) / 2
        let offsetY = (viewSize.height - scaledHeight) / 2
        
        return contour.map { point in
            CGPoint(
                x: point.x * scale + offsetX,
                y: point.y * scale + offsetY
            )
        }
    }
    
    var body: some View {
        ZStack {
            if !contour.isEmpty && scaledContour.count > 2 {
                // Ultra thin material background
                Path { path in
                    path.move(to: scaledContour[0])
                    for i in 1..<scaledContour.count {
                        path.addLine(to: scaledContour[i])
                    }
                    path.closeSubpath()
                }
                .fill(.ultraThinMaterial)
                .opacity(0.6)
                
                // Draw the contour outline
                Path { path in
                    path.move(to: scaledContour[0])
                    for i in 1..<scaledContour.count {
                        path.addLine(to: scaledContour[i])
                    }
                    path.closeSubpath()
                }
                .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
                .shadow(color: .green.opacity(0.6), radius: 8)
            }
        }
    }
}