import SwiftUI

struct CategoryGuidelineSetupView: View {
    let category: PhotoCategory
    @State private var showingCamera = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "person.crop.rectangle.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.bodyLapseTurquoise)
            
            VStack(spacing: 12) {
                Text("guideline.setup.title".localized)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(category.name)
                    .font(.headline)
                    .foregroundColor(.bodyLapseTurquoise)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(20)
                
                Text("guideline.setup.description".localized)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 16) {
                Button(action: {
                    showingCamera = true
                }) {
                    Text("guideline.setup.start".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.bodyLapseTurquoise)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                
                Button(action: {
                    dismiss()
                }) {
                    Text("common.cancel".localized)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .navigationTitle("guideline.setup.nav_title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: Button(action: {
            dismiss()
        }) {
            Image(systemName: "xmark")
                .foregroundColor(.secondary)
        })
        .fullScreenCover(isPresented: $showingCamera, onDismiss: {
            // ResetGuidelineViewが閉じられた時にこのビューを自動で閉じる
            dismiss()
        }) {
            ResetGuidelineView(categoryId: category.id, categoryName: category.name)
        }
    }
}

#Preview {
    NavigationView {
        CategoryGuidelineSetupView(category: PhotoCategory.defaultCategory)
    }
}