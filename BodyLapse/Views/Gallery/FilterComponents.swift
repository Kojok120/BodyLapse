import SwiftUI

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? Color.bodyLapseTurquoise : Color(UIColor.tertiarySystemBackground)
                )
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(isSelected ? Color.clear : Color(UIColor.separator).opacity(0.5), lineWidth: 1)
                )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(minWidth: 60)
                .background(
                    isSelected ? Color.bodyLapseTurquoise : Color(UIColor.tertiarySystemBackground)
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Color(UIColor.separator).opacity(0.3), lineWidth: 1)
                )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Filter Options View

struct FilterOptionsView: View {
    @ObservedObject var viewModel: GalleryViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("gallery.filter.category".localized) {
                    if viewModel.availableCategories.count > 1 && SubscriptionManagerService.shared.isPremium {
                        ForEach(viewModel.availableCategories) { category in
                            HStack {
                                Text(category.name)
                                Spacer()
                                if viewModel.selectedCategories.contains(category.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.bodyLapseTurquoise)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.toggleCategory(category.id)
                            }
                        }
                    } else {
                        Text("gallery.filter.all_categories".localized)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("gallery.filter.sort".localized) {
                    ForEach(GalleryViewModel.SortOrder.allCases, id: \.self) { order in
                        HStack {
                            Text(order.localizedString)
                            Spacer()
                            if viewModel.sortOrder == order {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.bodyLapseTurquoise)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.sortOrder = order
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        viewModel.clearFilters()
                    }) {
                        Text("gallery.filter.reset".localized)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("gallery.filter".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}