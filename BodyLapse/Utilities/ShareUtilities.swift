import UIKit
import SwiftUI

// MARK: - 共有設定

struct ShareConfiguration {
    var excludeProblematicExtensions: Bool = false
    var enableErrorLogging: Bool = true
    var useEnhancedShareSheet: Bool = false
    
    static let `default` = ShareConfiguration()
    
    // "Connection to plugin invalidated"エラーを引き起こす可能性のある既知の問題のあるアクティビティタイプ
    static let problematicActivityTypes: [UIActivity.ActivityType] = [
        // 必要に応じて特定のアクティビティタイプをここに追加
        // UIActivity.ActivityType("jp.naver.line.Share") // これはパブリック定数ではないため動作しません
    ]
}

// MARK: - 共有マネージャー

class ShareManager {
    static let shared = ShareManager()
    
    private init() {}
    
    func createShareSheet(
        activityItems: [Any],
        configuration: ShareConfiguration = .default,
        onDismiss: (() -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) -> AnyView {
        
        if configuration.useEnhancedShareSheet {
            return AnyView(
                EnhancedShareSheet(
                    activityItems: activityItems,
                    excludedActivityTypes: configuration.excludeProblematicExtensions ? ShareConfiguration.problematicActivityTypes : [],
                    onDismiss: onDismiss,
                    onError: onError
                )
            )
        } else {
            return AnyView(
                ShareSheet(
                    activityItems: activityItems,
                    onDismiss: onDismiss
                )
            )
        }
    }
    
    func logShareError(_ error: Error, context: String = "") {
        let errorMessage = "ShareSheet Error \(context): \(error.localizedDescription)"
        print("🚨 \(errorMessage)")
        
        // 特定のLINEプラグインエラーか確認
        if error.localizedDescription.contains("plugin invalidated") ||
           error.localizedDescription.contains("Connection to plugin") {
            print("📱 This appears to be a known iOS share extension issue. The sharing may still work despite this error.")
        }
    }
}

// MARK: - 共有エラータイプ

enum ShareError: LocalizedError {
    case pluginConnectionInvalidated
    case shareExtensionUnavailable
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .pluginConnectionInvalidated:
            return "Share plugin connection was invalidated. This is a known iOS issue and sharing may still work."
        case .shareExtensionUnavailable:
            return "The selected sharing app is currently unavailable."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - 共有デバッグヘルパー

struct ShareDebugHelper {
    static func logShareAttempt(activityItems: [Any]) {
        print("🔄 ShareSheet: Attempting to share \(activityItems.count) items")
        for (index, item) in activityItems.enumerated() {
            print("   Item \(index): \(type(of: item))")
        }
    }
    
    static func logActivityType(_ activityType: UIActivity.ActivityType?) {
        if let activityType = activityType {
            print("📤 ShareSheet: Selected activity type: \(activityType.rawValue)")
            
            // 問題のある拡張機能か確認
            if activityType.rawValue.contains("line") ||
               activityType.rawValue.contains("LINE") {
                print("⚠️ ShareSheet: LINE sharing detected - monitoring for plugin connection issues")
            }
        }
    }
}

// MARK: - SwiftUIヘルパー拡張

extension View {
    func shareSheet(
        isPresented: Binding<Bool>,
        activityItems: [Any],
        configuration: ShareConfiguration = .default,
        onDismiss: (() -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            ShareManager.shared.createShareSheet(
                activityItems: activityItems,
                configuration: configuration,
                onDismiss: {
                    isPresented.wrappedValue = false
                    onDismiss?()
                },
                onError: { error in
                    ShareManager.shared.logShareError(error, context: "Custom ShareSheet")
                    onError?(error)
                }
            )
        }
    }
}