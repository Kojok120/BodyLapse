import SwiftUI
import PhotosUI

struct PhotoImportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PhotoImportViewModel()
    @State private var selectedDate = Date()
    @State private var selectedCategory: String = CategoryStorageService.shared.getActiveCategories().first?.id ?? ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var weight: String = ""
    @State private var bodyFat: String = ""
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    private let isPremium: Bool = SubscriptionManagerService.shared.isPremium
    
    var body: some View {
        NavigationView {
            Form {
                // Instructions Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("import_export.photo_import_instruction1".localized, systemImage: "1.circle.fill")
                        Label("import_export.photo_import_instruction2".localized, systemImage: "2.circle.fill")
                        Label("import_export.photo_import_instruction3".localized, systemImage: "3.circle.fill")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                } header: {
                    Text("import_export.how_to_import_photos".localized)
                }
                
                // Photo Selection
                Section {
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: 1,
                        matching: .images
                    ) {
                        HStack {
                            Image(systemName: "photo")
                                .foregroundColor(.bodyLapseTurquoise)
                            Text(selectedItems.isEmpty ? "import_export.select_photo".localized : "import_export.photo_selected".localized)
                            Spacer()
                            if !selectedItems.isEmpty {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    DatePicker("import_export.photo_date".localized, selection: $selectedDate, displayedComponents: .date)
                    
                    if CategoryStorageService.shared.getActiveCategories().count > 1 {
                        Picker("import_export.category".localized, selection: $selectedCategory) {
                            ForEach(CategoryStorageService.shared.getActiveCategories()) { category in
                                Text(category.name).tag(category.id)
                            }
                        }
                    }
                } header: {
                    Text("import_export.photo_details".localized)
                }
                
                // Weight Data (Premium only)
                if isPremium {
                    Section {
                        HStack {
                            Text("weight_tracking.weight".localized)
                            Spacer()
                            TextField("photo.enter_value".localized, text: $weight)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text(UserDefaults.standard.string(forKey: "weight_unit") ?? "kg")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("weight_tracking.body_fat".localized)
                            Spacer()
                            TextField("photo.enter_value".localized, text: $bodyFat)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("unit.percent".localized)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("weight_tracking.data".localized)
                    } footer: {
                        Text("import_export.weight_data_optional".localized)
                            .font(.caption)
                    }
                }
                
                // Import Button
                Section {
                    Button(action: importPhoto) {
                        HStack {
                            Spacer()
                            if viewModel.isImporting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            } else {
                                Text("import_export.import_photo".localized)
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(selectedItems.isEmpty || viewModel.isImporting)
                }
            }
            .navigationTitle("import_export.import_single_photo".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
            }
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("common.ok".localized) {
                    if viewModel.importSuccessful {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func importPhoto() {
        guard let item = selectedItems.first else { return }
        
        Task {
            await viewModel.importPhoto(
                item: item,
                date: selectedDate,
                categoryId: selectedCategory,
                weight: Double(weight),
                bodyFat: Double(bodyFat)
            )
            
            if let error = viewModel.errorMessage {
                alertTitle = "common.error".localized
                alertMessage = error
                showingAlert = true
            } else {
                alertTitle = "import_export.import_success".localized
                alertMessage = "import_export.photo_imported_successfully".localized
                showingAlert = true
            }
        }
    }
}

@MainActor
class PhotoImportViewModel: ObservableObject {
    @Published var isImporting = false
    @Published var errorMessage: String?
    @Published var importSuccessful = false
    
    func importPhoto(item: PhotosPickerItem, date: Date, categoryId: String, weight: Double?, bodyFat: Double?) async {
        isImporting = true
        errorMessage = nil
        importSuccessful = false
        
        do {
            // Load the image data
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw NSError(domain: "PhotoImport", code: 1, userInfo: [NSLocalizedDescriptionKey: "import_export.invalid_image".localized])
            }
            
            // Check if photo already exists for this date and category
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)
            if PhotoStorageService.shared.photoExists(for: dateString, categoryId: categoryId) {
                throw NSError(domain: "PhotoImport", code: 2, userInfo: [NSLocalizedDescriptionKey: "import_export.photo_already_exists".localized])
            }
            
            // Save the photo with weight data if provided
            _ = try PhotoStorageService.shared.savePhoto(
                image,
                captureDate: date,
                categoryId: categoryId,
                weight: weight,
                bodyFatPercentage: bodyFat
            )
            
            // Save weight data if provided (through HealthKit if enabled)
            if let weight = weight, weight > 0 {
                // Try to save through HealthKit
                HealthKitService.shared.saveWeight(weight, date: date) { _, _ in }
                if let bodyFat = bodyFat, bodyFat > 0 {
                    HealthKitService.shared.saveBodyFatPercentage(bodyFat / 100.0, date: date) { _, _ in }
                }
            }
            
            importSuccessful = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isImporting = false
    }
}