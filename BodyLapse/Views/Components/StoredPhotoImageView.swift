import SwiftUI

struct StoredPhotoImageView<Placeholder: View>: View {
    let photo: Photo
    let contentMode: ContentMode
    let scale: CGFloat
    private let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var requestedSize: CGSize = .zero

    init(
        photo: Photo,
        contentMode: ContentMode = .fit,
        scale: CGFloat = UIScreen.main.scale,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.photo = photo
        self.contentMode = contentMode
        self.scale = scale
        self.placeholder = placeholder
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } else {
                    placeholder()
                }
            }
            .onAppear {
                updateRequestedSize(geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                updateRequestedSize(newSize)
            }
        }
        .task(id: loadTaskID) {
            await loadImage()
        }
    }

    private var loadTaskID: String {
        let width = Int(max(1, requestedSize.width * scale))
        let height = Int(max(1, requestedSize.height * scale))
        return "\(photo.id.uuidString)_\(width)x\(height)"
    }

    @MainActor
    private func updateRequestedSize(_ size: CGSize) {
        let clamped = CGSize(width: max(size.width, 1), height: max(size.height, 1))
        guard !isApproximatelyEqual(clamped, requestedSize) else { return }
        requestedSize = clamped
    }

    @MainActor
    private func loadImage() async {
        guard requestedSize.width > 0, requestedSize.height > 0 else { return }

        let targetSize = requestedSize
        let targetScale = scale
        let targetPhoto = photo

        image = nil

        let loadedImage = await Task.detached(priority: .userInitiated) {
            PhotoStorageService.shared.loadImage(for: targetPhoto, targetSize: targetSize, scale: targetScale)
        }.value

        guard !Task.isCancelled else { return }
        guard isApproximatelyEqual(requestedSize, targetSize) else { return }

        image = loadedImage
    }

    private func isApproximatelyEqual(_ lhs: CGSize, _ rhs: CGSize) -> Bool {
        abs(lhs.width - rhs.width) < 1 && abs(lhs.height - rhs.height) < 1
    }
}
