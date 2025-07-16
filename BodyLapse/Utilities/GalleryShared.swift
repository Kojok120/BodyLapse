import SwiftUI

// MARK: - Shared Gallery Components

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

// MARK: - Gallery Utilities

struct GalleryUtilities {
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
    
    static func showSaveSuccess(message: String, showingSaveSuccess: Binding<Bool>, saveSuccessMessage: Binding<String>) {
        saveSuccessMessage.wrappedValue = message
        withAnimation {
            showingSaveSuccess.wrappedValue = true
        }
    }
}

// MARK: - Gallery Actions Protocol

protocol GalleryItemActions {
    func onTap()
    func onDelete()
    func onSave()
    func onShare()
}

// MARK: - Save Success Toast

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