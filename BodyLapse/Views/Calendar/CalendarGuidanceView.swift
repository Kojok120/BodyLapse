import SwiftUI

struct CalendarGuidanceView: View {
    @Binding var showingVideoGuidance: Bool
    @Binding var showingCategoryGuidance: Bool
    @Binding var showingVideoGeneration: Bool
    @Binding var showingAddCategory: Bool
    
    @StateObject private var tooltipManager = TooltipManager.shared
    
    var body: some View {
        ZStack {
            // Video guidance overlay
            if showingVideoGuidance {
                videoGuidanceOverlay
            }
            
            // Category guidance overlay
            if showingCategoryGuidance {
                categoryGuidanceOverlay
            }
        }
    }
    
    // MARK: - Video Guidance Overlay
    private var videoGuidanceOverlay: some View {
        Color.black.opacity(0.1)
            .ignoresSafeArea()
            .onTapGesture {
                dismissVideoGuidance()
            }
            .overlay(
                GeometryReader { geometry in
                    VStack {
                        // Position tooltip above the button area
                        HStack {
                            Spacer()
                            videoGuidanceTooltip
                                .padding(.trailing, 25) // Align with button position
                        }
                        .padding(.top, 75) // Move closer to button
                        
                        Spacer()
                    }
                }
            )
    }
    
    private var videoGuidanceTooltip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tooltipManager.getTitle(for: .videoGeneration))
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    dismissVideoGuidance()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Text(tooltipManager.getDescription(for: .videoGeneration))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
            
            Button(action: {
                dismissVideoGuidance()
            }) {
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
        .scaleEffect(showingVideoGuidance ? 1.0 : 0.8)
        .opacity(showingVideoGuidance ? 1.0 : 0.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingVideoGuidance)
    }
    
    // MARK: - Category Guidance Overlay
    private var categoryGuidanceOverlay: some View {
        Color.black.opacity(0.1)
            .ignoresSafeArea()
            .onTapGesture {
                dismissCategoryGuidance()
            }
            .overlay(
                GeometryReader { geometry in
                    VStack {
                        // Position tooltip above the button area
                        HStack {
                            categoryGuidanceTooltip
                                .padding(.leading, 50) // Align with plus button position (account for "正面" button width)
                            Spacer()
                        }
                        .padding(.top, 50) // Move closer to button
                        
                        Spacer()
                    }
                }
            )
    }
    
    private var categoryGuidanceTooltip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tooltipManager.getTitle(for: .categoryAdding))
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    dismissCategoryGuidance()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Text(tooltipManager.getDescription(for: .categoryAdding))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
            
            Button(action: {
                dismissCategoryGuidance()
            }) {
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
        .scaleEffect(showingCategoryGuidance ? 1.0 : 0.8)
        .opacity(showingCategoryGuidance ? 1.0 : 0.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingCategoryGuidance)
    }
    
    // MARK: - Guidance Helper Methods
    private func dismissVideoGuidance() {
        showingVideoGuidance = false
        tooltipManager.markFeatureCompleted(for: .videoGeneration)
        
        // After dismissing guidance, proceed with video generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showingVideoGeneration = true
        }
    }
    
    private func dismissCategoryGuidance() {
        showingCategoryGuidance = false
        tooltipManager.markFeatureCompleted(for: .categoryAdding)
        
        // After dismissing guidance, proceed with adding category
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showingAddCategory = true
        }
    }
}