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
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Configure popover presentation for iPad
        if let popover = uiViewController.popoverPresentationController {
            popover.sourceView = context.coordinator.sourceView
            popover.sourceRect = CGRect(x: context.coordinator.sourceView?.bounds.midX ?? 0,
                                      y: context.coordinator.sourceView?.bounds.midY ?? 0,
                                      width: 0, height: 0)
            popover.permittedArrowDirections = .any
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UIActivityItemSource {
        var onDismiss: (() -> Void)?
        weak var sourceView: UIView?
        
        override init() {
            super.init()
            // Get the root view controller's view as source
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                sourceView = window.rootViewController?.view
            }
        }
        
        // MARK: - UIActivityItemSource
        
        func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
            return ""
        }
        
        func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
            return nil
        }
    }
}

// MARK: - Enhanced ShareSheet with better error handling

struct EnhancedShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType] = []
    var onDismiss: (() -> Void)?
    var onError: ((Error) -> Void)?
    
    func makeUIViewController(context: Context) -> ShareSheetViewController {
        let controller = ShareSheetViewController(
            activityItems: activityItems,
            excludedActivityTypes: excludedActivityTypes
        )
        
        controller.onDismiss = onDismiss
        controller.onError = onError
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ShareSheetViewController, context: Context) {
        // Update if needed
    }
}

class ShareSheetViewController: UIViewController {
    private let activityItems: [Any]
    private let excludedActivityTypes: [UIActivity.ActivityType]
    private var activityViewController: UIActivityViewController?
    
    var onDismiss: (() -> Void)?
    var onError: ((Error) -> Void)?
    
    init(activityItems: [Any], excludedActivityTypes: [UIActivity.ActivityType] = []) {
        self.activityItems = activityItems
        self.excludedActivityTypes = excludedActivityTypes
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentShareSheet()
    }
    
    private func presentShareSheet() {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // Configure for better stability
        controller.excludedActivityTypes = excludedActivityTypes
        controller.isModalInPresentation = true
        
        // Set completion handler
        controller.completionWithItemsHandler = { [weak self] activity, completed, returnedItems, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("ShareSheet error: \(error.localizedDescription)")
                    self?.onError?(error)
                }
                self?.dismiss(animated: false) {
                    self?.onDismiss?()
                }
            }
        }
        
        // Configure popover for iPad
        if let popover = controller.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // Store reference and present
        activityViewController = controller
        present(controller, animated: true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Ensure cleanup
        if activityViewController?.presentingViewController != nil {
            activityViewController?.dismiss(animated: false)
        }
        activityViewController = nil
    }
}