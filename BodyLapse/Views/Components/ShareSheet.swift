import SwiftUI

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var onDismiss: (() -> Void)?
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // Set completion handler to prevent multiple dismissals
        controller.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async {
                onDismiss?()
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Check if controller is already presented to prevent multiple dismissals
        guard uiViewController.presentedViewController == nil else {
            return
        }
    }
}