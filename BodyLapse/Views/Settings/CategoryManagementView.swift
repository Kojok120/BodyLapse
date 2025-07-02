//
//  CategoryManagementView.swift
//  BodyLapse
//
//  Created by Anthropic on 2025/01/01.
//

import SwiftUI

struct CategoryManagementView: View {
    @ObservedObject private var userSettings = UserSettingsManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManagerService.shared
    @State private var categories: [PhotoCategory] = []
    @State private var showingAddCategory = false
    @State private var showingEditCategory = false
    @State private var categoryToEdit: PhotoCategory?
    @State private var showingDeleteConfirmation = false
    @State private var categoryToDelete: PhotoCategory?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        if subscriptionManager.isPremium {
        List {
            Section {
                ForEach(categories) { category in
                    CategoryRowView(
                        category: category,
                        onEdit: {
                            categoryToEdit = category
                            showingEditCategory = true
                        },
                        onDelete: {
                            if category.canBeDeleted {
                                categoryToDelete = category
                                showingDeleteConfirmation = true
                            }
                        },
                        onResetGuideline: {
                            // Navigation handled in CategoryRowView
                        }
                    )
                }
                .onMove(perform: moveCategories)
            } header: {
                Text("category.management.list_header".localized)
            } footer: {
                Text(String(format: "category.management.list_footer".localized, PhotoCategory.maxCustomCategories + 1, PhotoCategory.maxCustomCategories))
                    .font(.caption)
            }
            
            if subscriptionManager.isPremium && CategoryStorageService.shared.canAddMoreCategories() {
                Section {
                    Button(action: {
                        showingAddCategory = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.bodyLapseTurquoise)
                            Text("category.management.add_category".localized)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .navigationTitle("category.management.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCategories()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("GuidelineUpdated"))) { notification in
            // Reload categories when guideline is updated
            print("CategoryManagementView: Received GuidelineUpdated notification")
            if let categoryId = notification.userInfo?["categoryId"] as? String {
                print("CategoryManagementView: Updated category ID: \(categoryId)")
            }
            loadCategories()
            print("CategoryManagementView: Categories reloaded, count: \(categories.count)")
            // Print guideline status for each category
            for category in categories {
                print("CategoryManagementView: Category \(category.name) - has guideline: \(category.guideline != nil)")
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView { newCategory in
                if CategoryStorageService.shared.addCategory(newCategory) {
                    loadCategories()
                } else {
                    alertMessage = "category.management.add_failed".localized
                    showingAlert = true
                }
            }
        }
        .sheet(item: $categoryToEdit) { category in
            EditCategoryView(category: category) { updatedCategory in
                CategoryStorageService.shared.updateCategory(updatedCategory)
                loadCategories()
            }
        }
        .alert("category.management.delete_title".localized, isPresented: $showingDeleteConfirmation) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("category.management.delete".localized, role: .destructive) {
                if let category = categoryToDelete {
                    deleteCategory(category)
                }
            }
        } message: {
            Text(String(format: "category.management.delete_warning".localized, categoryToDelete?.name ?? ""))
        }
        .alert("common.error".localized, isPresented: $showingAlert) {
            Button("common.ok".localized) {}
        } message: {
            Text(alertMessage)
        }
        } else {
            // Premium upgrade prompt view
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.bodyLapseTurquoise)
                
                VStack(spacing: 12) {
                    Text("category.premium.title".localized)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("category.premium.description".localized)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Label("category.premium.feature1".localized, systemImage: "camera.on.rectangle")
                    Label("category.premium.feature2".localized, systemImage: "person.crop.rectangle")
                    Label("category.premium.feature3".localized, systemImage: "square.split.2x2")
                    Label("category.premium.feature4".localized, systemImage: "line.3.horizontal.decrease.circle")
                }
                .font(.subheadline)
                .padding(.horizontal, 40)
                
                NavigationLink(destination: PremiumView()) {
                    Text("category.premium.upgrade".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.bodyLapseTurquoise)
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
            }
            .navigationTitle("category.management.title".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func loadCategories() {
        print("CategoryManagementView: loadCategories() called")
        let newCategories = CategoryStorageService.shared.getActiveCategories()
        print("CategoryManagementView: Loaded \(newCategories.count) categories")
        for category in newCategories {
            print("CategoryManagementView: - \(category.name) (ID: \(category.id)), guideline: \(category.guideline != nil)")
        }
        // Force a state update by clearing and resetting
        categories = []
        DispatchQueue.main.async {
            self.categories = newCategories
        }
    }
    
    private func moveCategories(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
        
        // Update order in storage
        for (index, category) in categories.enumerated() {
            var updatedCategory = category
            updatedCategory.order = index
            CategoryStorageService.shared.updateCategory(updatedCategory)
        }
    }
    
    private func deleteCategory(_ category: PhotoCategory) {
        CategoryStorageService.shared.deleteCategory(id: category.id)
        loadCategories()
    }
}

struct CategoryRowView: View {
    let category: PhotoCategory
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onResetGuideline: () -> Void
    @State private var showingGuidelineSetup = false
    @State private var hasGuideline: Bool = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.body)
                
                HStack {
                    if category.isDefault {
                        Label("category.management.default".localized, systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if hasGuideline {
                        Label("category.management.guideline_set".localized, systemImage: "person.crop.rectangle")
                            .font(.caption)
                            .foregroundColor(.bodyLapseTurquoise)
                    }
                }
            }
            
            Spacer()
            
            if !category.isDefault {
                Menu {
                    Button(action: onEdit) {
                        Label("category.management.edit_name_action".localized, systemImage: "pencil")
                    }
                    
                    Button(action: {
                        showingGuidelineSetup = true
                    }) {
                        Label("category.management.set_guideline".localized, systemImage: "person.crop.rectangle.badge.plus")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: onDelete) {
                        Label("category.management.delete".localized, systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
            } else {
                Button(action: {
                    showingGuidelineSetup = true
                }) {
                    Image(systemName: "person.crop.rectangle.badge.plus")
                        .foregroundColor(.bodyLapseTurquoise)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 4)
        .background(
            NavigationLink(destination: CategoryGuidelineSetupView(category: category), isActive: $showingGuidelineSetup) {
                EmptyView()
            }
            .hidden()
        )
        .onAppear {
            hasGuideline = category.guideline != nil
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("GuidelineUpdated"))) { notification in
            if let categoryId = notification.userInfo?["categoryId"] as? String,
               categoryId == category.id {
                // Reload this specific category's guideline status
                if let updatedCategory = CategoryStorageService.shared.getCategoryById(categoryId) {
                    hasGuideline = updatedCategory.guideline != nil
                    print("CategoryRowView: Updated guideline status for \(category.name): \(hasGuideline)")
                }
            }
        }
    }
}

struct AddCategoryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var categoryName = ""
    let onAdd: (PhotoCategory) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("category.management.category_name".localized, text: $categoryName)
                        .onChange(of: categoryName) { _, newValue in
                            if newValue.count > 10 {
                                categoryName = String(newValue.prefix(10))
                            }
                        }
                } header: {
                    Text("category.management.new_category".localized)
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("category.management.example".localized)
                        Text("\(categoryName.count)/10")
                            .font(.caption)
                            .foregroundColor(categoryName.count == 10 ? .orange : .secondary)
                    }
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
                            name: categoryName,
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

struct EditCategoryView: View {
    @Environment(\.dismiss) var dismiss
    let category: PhotoCategory
    @State private var categoryName: String
    let onUpdate: (PhotoCategory) -> Void
    
    init(category: PhotoCategory, onUpdate: @escaping (PhotoCategory) -> Void) {
        self.category = category
        self._categoryName = State(initialValue: category.name)
        self.onUpdate = onUpdate
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("category.management.category_name".localized, text: $categoryName)
                        .onChange(of: categoryName) { _, newValue in
                            if newValue.count > 10 {
                                categoryName = String(newValue.prefix(10))
                            }
                        }
                } header: {
                    Text("category.management.edit_name".localized)
                } footer: {
                    Text("\(categoryName.count)/10")
                        .font(.caption)
                        .foregroundColor(categoryName.count == 10 ? .orange : .secondary)
                }
            }
            .navigationTitle("category.management.edit".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.save".localized) {
                        var updatedCategory = category
                        updatedCategory.name = categoryName
                        onUpdate(updatedCategory)
                        dismiss()
                    }
                    .disabled(categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        CategoryManagementView()
    }
}