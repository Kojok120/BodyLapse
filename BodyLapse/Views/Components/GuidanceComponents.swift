import SwiftUI

// MARK: - Guidance Badge (Red Dot)
struct GuidanceBadge: View {
    let isVisible: Bool
    let size: CGFloat
    let offset: CGPoint
    
    init(isVisible: Bool, size: CGFloat = 8, offset: CGPoint = CGPoint(x: 0, y: 0)) {
        self.isVisible = isVisible
        self.size = size
        self.offset = offset
    }
    
    var body: some View {
        if isVisible {
            Circle()
                .fill(Color.red)
                .frame(width: size, height: size)
                .offset(x: offset.x, y: offset.y)
                .animation(.easeInOut(duration: 0.2), value: isVisible)
        }
    }
}

// MARK: - Guidance Tooltip
struct GuidanceTooltip: View {
    let title: String
    let description: String
    let isVisible: Bool
    let onDismiss: () -> Void
    
    @State private var showContent = false
    
    var body: some View {
        if isVisible {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                
                Button(action: onDismiss) {
                    HStack {
                        Spacer()
                        Text("guidance.got_it".localized)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.2))
                    )
                }
                .padding(.top, 4)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.85))
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            .frame(maxWidth: 280)
            .scaleEffect(showContent ? 1.0 : 0.8)
            .opacity(showContent ? 1.0 : 0.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showContent)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.1)) {
                    showContent = true
                }
            }
        }
    }
}

// MARK: - Guidance Wrapper ViewModifier
struct GuidanceModifier: ViewModifier {
    let featureID: TooltipManager.FeatureID
    @ObservedObject private var tooltipManager = TooltipManager.shared
    @State private var showTooltip = false
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .onTapGesture {
                    handleTap()
                }
                .overlay(
                    // Badge positioning
                    GuidanceBadge(
                        isVisible: tooltipManager.needsGuidance(for: featureID),
                        size: 10,
                        offset: CGPoint(x: 8, y: -8)
                    ),
                    alignment: .topTrailing
                )
            
            // Tooltip overlay
            if showTooltip {
                Color.black.opacity(0.1)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissTooltip()
                    }
                
                VStack {
                    Spacer()
                    
                    GuidanceTooltip(
                        title: tooltipManager.getTitle(for: featureID),
                        description: tooltipManager.getDescription(for: featureID),
                        isVisible: showTooltip,
                        onDismiss: {
                            dismissTooltip()
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                    
                    Spacer()
                }
            }
        }
    }
    
    private func handleTap() {
        // Only show tooltip if guidance is needed and hasn't been shown before
        if tooltipManager.needsGuidance(for: featureID) && !tooltipManager.hasShownTooltip(for: featureID) {
            showTooltip = true
            tooltipManager.markTooltipShown(for: featureID)
        }
    }
    
    private func dismissTooltip() {
        showTooltip = false
        tooltipManager.markFeatureCompleted(for: featureID)
    }
}

// MARK: - View Extension for Easy Usage
extension View {
    func withGuidance(for featureID: TooltipManager.FeatureID) -> some View {
        self.modifier(GuidanceModifier(featureID: featureID))
    }
}

// MARK: - Guidance Badge Only (for custom implementations)
struct GuidanceBadgeOnly: ViewModifier {
    let featureID: TooltipManager.FeatureID
    let size: CGFloat
    let offset: CGPoint
    @ObservedObject private var tooltipManager = TooltipManager.shared
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GuidanceBadge(
                    isVisible: tooltipManager.needsGuidance(for: featureID),
                    size: size,
                    offset: offset
                ),
                alignment: .topTrailing
            )
    }
}

extension View {
    func withGuidanceBadge(
        for featureID: TooltipManager.FeatureID,
        size: CGFloat = 10,
        offset: CGPoint = CGPoint(x: 8, y: -8)
    ) -> some View {
        self.modifier(GuidanceBadgeOnly(featureID: featureID, size: size, offset: offset))
    }
}

// MARK: - Custom Guidance Handler (for buttons that need custom behavior)
struct CustomGuidanceHandler: ViewModifier {
    let featureID: TooltipManager.FeatureID
    let onGuidanceNeeded: () -> Void
    @ObservedObject private var tooltipManager = TooltipManager.shared
    
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                if tooltipManager.needsGuidance(for: featureID) && !tooltipManager.hasShownTooltip(for: featureID) {
                    tooltipManager.markTooltipShown(for: featureID)
                    onGuidanceNeeded()
                }
            }
    }
}

extension View {
    func withCustomGuidance(
        for featureID: TooltipManager.FeatureID,
        onGuidanceNeeded: @escaping () -> Void
    ) -> some View {
        self.modifier(CustomGuidanceHandler(featureID: featureID, onGuidanceNeeded: onGuidanceNeeded))
    }
}