import SwiftUI

// MARK: - 共通ギャラリーコンポーネント

enum GalleryActiveSheet: Identifiable {
    case shareOptions(Photo)
    case share([Any])
    
    var id: String {
        switch self {
        case .shareOptions: return "shareOptions"
        case .share: return "share"
        }
    }
}

// MARK: - ギャラリーユーティリティ

struct GalleryUtilities {
    /// セルの日付。セルごとに DateFormatter を作らず、アプリの言語の書式を使い回す
    static func formatDate(_ date: Date) -> String {
        AppDateFormat.monthDay(date)
    }
}

// MARK: - 保存成功トースト

struct SaveSuccessToast: View {
    let message: String
    @Binding var isShowing: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
            
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding(.top, 50)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    isShowing = false
                }
            }
        }
    }
}