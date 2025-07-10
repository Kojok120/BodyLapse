import SwiftUI

struct CalendarHeaderView: View {
    let isPremium: Bool
    let availableCategories: [PhotoCategory]
    let selectedCategory: PhotoCategory
    @Binding var selectedPeriod: TimePeriod
    @Binding var showingPeriodPicker: Bool
    @Binding var showingDatePicker: Bool
    @Binding var showingVideoGeneration: Bool
    @Binding var showingAddCategory: Bool
    let isGeneratingVideo: Bool
    let onCategorySelect: (PhotoCategory) -> Void
    
    // Guidance system callbacks
    let onVideoGuidanceRequested: () -> Void
    let onCategoryGuidanceRequested: () -> Void
    
    // Guidance system state
    @StateObject private var tooltipManager = TooltipManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            // Category selection (Premium feature)
            if isPremium {
                categorySelector
            }
            
            HStack {
                periodAndDateSelectors
                
                Spacer()
                
                generateVideoButton
            }
            .padding(.horizontal)
        }
    }
    
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(availableCategories) { category in
                    Button(action: {
                        onCategorySelect(category)
                    }) {
                        Text(category.name)
                            .font(.system(size: 14, weight: selectedCategory.id == category.id ? .semibold : .regular))
                            .foregroundColor(selectedCategory.id == category.id ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedCategory.id == category.id ? Color.bodyLapseTurquoise : Color(UIColor.secondarySystemBackground))
                            )
                    }
                }
                
                // Add category button
                if CategoryStorageService.shared.canAddMoreCategories() {
                    Button(action: {
                        handleCategoryAddingTap()
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(UIColor.secondarySystemBackground))
                            )
                    }
                    .overlay(
                        // Guidance badge
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .offset(x: 8, y: -8)
                            .opacity(tooltipManager.needsGuidance(for: .categoryAdding) ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.2), value: tooltipManager.needsGuidance(for: .categoryAdding)),
                        alignment: .topTrailing
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var periodAndDateSelectors: some View {
        HStack(spacing: 8) {
            Button(action: {
                showingPeriodPicker = true
            }) {
                HStack {
                    Text(selectedPeriod.localizedString)
                        .font(.system(size: 16, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
            }
            
            Button(action: {
                showingDatePicker = true
            }) {
                Image(systemName: "calendar")
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
                    .padding(8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
            }
        }
    }
    
    private var generateVideoButton: some View {
        Button(action: {
            handleVideoGenerationTap()
        }) {
            HStack {
                Image(systemName: "video.fill")
                Text("calendar.generate".localized)
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.bodyLapseYellow)
            .cornerRadius(20)
        }
        .disabled(isGeneratingVideo)
        .overlay(
            // Guidance badge
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .offset(x: 8, y: -8)
                .opacity(tooltipManager.needsGuidance(for: .videoGeneration) ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.2), value: tooltipManager.needsGuidance(for: .videoGeneration)),
            alignment: .topTrailing
        )
    }
    
    // MARK: - Helper Methods
    private func handleVideoGenerationTap() {
        // Check if guidance is needed
        if tooltipManager.needsGuidance(for: .videoGeneration) && !tooltipManager.hasShownTooltip(for: .videoGeneration) {
            // Mark as shown and request guidance display
            tooltipManager.markTooltipShown(for: .videoGeneration)
            onVideoGuidanceRequested()
        } else {
            // No guidance needed, proceed with video generation
            showingVideoGeneration = true
        }
    }
    
    private func handleCategoryAddingTap() {
        // Check if guidance is needed
        if tooltipManager.needsGuidance(for: .categoryAdding) && !tooltipManager.hasShownTooltip(for: .categoryAdding) {
            // Mark as shown and request guidance display
            tooltipManager.markTooltipShown(for: .categoryAdding)
            onCategoryGuidanceRequested()
        } else {
            // No guidance needed, proceed with adding category
            showingAddCategory = true
        }
    }
}