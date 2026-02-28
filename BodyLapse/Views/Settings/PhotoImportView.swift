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
    
    // 全機能が全ユーザーに利用可能
    private let isPremium: Bool = true
    
    var body: some View {
        NavigationView {
            Form {
                // 説明セクション
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
                
                // 写真選択
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
                
                // 体重データ - 全ユーザーに利用可能
                // 体重セクションを常に表示 {
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
                // }
                
                // インポートボタン
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
            // 画像データを読み込み
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw NSError(domain: "PhotoImport", code: 1, userInfo: [NSLocalizedDescriptionKey: "import_export.invalid_image".localized])
            }
            
            // この日付とカテゴリーの写真が既に存在するか確認
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)
            if PhotoStorageService.shared.photoExists(for: dateString, categoryId: categoryId) {
                throw NSError(domain: "PhotoImport", code: 2, userInfo: [NSLocalizedDescriptionKey: "import_export.photo_already_exists".localized])
            }
            
            // 体重データが提供されていれば写真と共に保存
            _ = try PhotoStorageService.shared.savePhoto(
                image,
                captureDate: date,
                categoryId: categoryId,
                weight: weight,
                bodyFatPercentage: bodyFat
            )
            
            // 体重データが提供されていれば保存（HealthKit有効時はHealthKit経由）
            if let weight = weight, weight > 0 {
                // HealthKit経由での保存を試行
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