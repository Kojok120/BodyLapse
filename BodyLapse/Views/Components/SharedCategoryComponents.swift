import SwiftUI

struct AddCategorySheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var categoryName = ""
    let onAdd: (PhotoCategory) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("category.management.category_name".localized, text: $categoryName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                } header: {
                    Text("category.management.new_category".localized)
                } footer: {
                    Text("category.management.example".localized)
                        .font(.caption)
                }
            }
            .navigationTitle("category.management.add_category".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("category.management.add".localized) {
                        let categories = CategoryStorageService.shared.getActiveCategories()
                        let maxOrder = categories.map { $0.order }.max() ?? 0
                        let newCategory = PhotoCategory.createCustomCategory(
                            name: categoryName.trimmingCharacters(in: .whitespacesAndNewlines),
                            order: maxOrder + 1
                        )
                        onAdd(newCategory)
                        dismiss()
                    }
                    .disabled(categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}