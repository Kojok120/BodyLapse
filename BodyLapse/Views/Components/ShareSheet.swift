import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var onDismiss: (() -> Void)?
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // Configure for better stability
        controller.isModalInPresentation = true
        
        // Set delegate for proper handling
        context.coordinator.onDismiss = onDismiss
        
        // Set completion handler with better error handling
        controller.completionWithItemsHandler = { activity, completed, returnedItems, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("ShareSheet error: \(error.localizedDescription)")
                }
                context.coordinator.onDismiss?()
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    final class Coordinator {
        var onDismiss: (() -> Void)?
    }
}
