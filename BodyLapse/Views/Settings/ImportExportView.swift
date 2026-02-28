import SwiftUI
import UniformTypeIdentifiers

struct ImportExportView: View {
    @StateObject private var viewModel = ImportExportViewModel()
    @State private var showingExportOptions = false
    @State private var showingImportPicker = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingHelp = false
    @State private var expandedSection: String? = nil
    
    var body: some View {
        NavigationView {
            List {
                // エクスポートセクション
                Section {
                    Button(action: {
                        showingExportOptions = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                                .foregroundColor(.bodyLapseTurquoise)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("import_export.export_data".localized)
                                    .font(.headline)
                                Text("import_export.export_description".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if viewModel.isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .disabled(viewModel.isExporting || viewModel.isImporting)
                } header: {
                    Text("import_export.export".localized)
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: {
                            withAnimation {
                                expandedSection = expandedSection == "export" ? nil : "export"
                            }
                        }) {
                            Label(expandedSection == "export" ? "import_export.show_less".localized : "import_export.learn_more".localized, 
                                  systemImage: expandedSection == "export" ? "chevron.up" : "info.circle")
                                .font(.caption)
                                .foregroundColor(.bodyLapseTurquoise)
                        }
                        
                        if expandedSection == "export" {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("import_export.export_detailed_guide".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Label("import_export.export_includes".localized, systemImage: "checkmark.circle")
                                    Label("import_export.export_format".localized, systemImage: "doc.zipper")
                                    Label("import_export.export_privacy".localized, systemImage: "lock.shield")
                                }
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                            .transition(.opacity)
                        }
                    }
                }
                
                // インポートセクション
                Section {
                    Button(action: {
                        showingImportPicker = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .font(.title2)
                                .foregroundColor(.bodyLapseTurquoise)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("import_export.import_data".localized)
                                    .font(.headline)
                                Text("import_export.import_description".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if viewModel.isImporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .disabled(viewModel.isExporting || viewModel.isImporting)
                } header: {
                    Text("import_export.import".localized)
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("import_export.import_footer".localized)
                            .font(.caption)
                        
                        Button(action: {
                            withAnimation {
                                expandedSection = expandedSection == "import" ? nil : "import"
                            }
                        }) {
                            Label(expandedSection == "import" ? "import_export.show_less".localized : "import_export.learn_more".localized, 
                                  systemImage: expandedSection == "import" ? "chevron.up" : "info.circle")
                                .font(.caption)
                                .foregroundColor(.bodyLapseTurquoise)
                        }
                        
                        if expandedSection == "import" {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("import_export.import_detailed_guide".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Label("import_export.merge_skip_detail".localized, systemImage: "arrow.right.circle")
                                    Label("import_export.merge_replace_detail".localized, systemImage: "arrow.triangle.2.circlepath")
                                }
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                            .transition(.opacity)
                        }
                    }
                }
                
                // 進捗セクション
                if viewModel.isExporting || viewModel.isImporting {
                    Section {
                        VStack(spacing: 12) {
                            Text(viewModel.progressMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            ProgressView(value: viewModel.progress)
                                .progressViewStyle(LinearProgressViewStyle())
                            
                            Text("\(Int(viewModel.progress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("import_export.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingHelp = true
                    }) {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
            .sheet(isPresented: $showingExportOptions) {
                ExportOptionsView(viewModel: viewModel)
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [UTType(filenameExtension: "bodylapse") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("common.ok".localized) { }
            } message: {
                Text(alertMessage)
            }
            .onChange(of: viewModel.exportCompleted) { _, completed in
                if completed {
                    handleExportCompletion()
                }
            }
            .onChange(of: viewModel.importCompleted) { _, completed in
                if completed {
                    handleImportCompletion()
                }
            }
            .onChange(of: viewModel.errorMessage) { _, errorMessage in
                if let errorMessage = errorMessage {
                    alertTitle = "common.error".localized
                    alertMessage = errorMessage
                    showingAlert = true
                }
            }
            .sheet(isPresented: $viewModel.showingImportOptions) {
                ImportOptionsSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingHelp) {
                ImportExportHelpView()
            }
        }
    }
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // セキュリティスコープリソースへのアクセスを開始
            guard url.startAccessingSecurityScopedResource() else {
                showError(NSError(
                    domain: "ImportError",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "import_export.permission_error".localized]
                ))
                return
            }
            
            // 完了時にリソースへのアクセスを確実に停止
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            // アクセス用に一時的な場所にファイルをコピー
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("BodyLapseImport_\(UUID().uuidString)_\(url.lastPathComponent)")
            
            do {
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                
                // メモリへの全ファイルロードを避けるため、セキュリティスコープアクセスがアクティブな間にコピー
                try FileManager.default.copyItem(at: url, to: tempURL)
                
                // Show import options
                viewModel.showImportOptions(for: tempURL)
            } catch {
                let nsError = error as NSError
                if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoPermissionError {
                    showError(NSError(
                        domain: "ImportError",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "import_export.file_access_error".localized]
                    ))
                } else {
                    showError(error)
                }
            }
            
        case .failure(let error):
            showError(error)
        }
    }
    
    private func handleExportCompletion() {
        if let exportURL = viewModel.exportedFileURL {
            // アラートを表示せずにファイルを即座に共有
            shareFile(exportURL)
        }
    }
    
    private func handleImportCompletion() {
        if let summary = viewModel.importSummary {
            alertTitle = "import_export.import_completed".localized
            alertMessage = String(format: "import_export.import_summary".localized,
                                   summary.photosImported,
                                   summary.videosImported,
                                   summary.categoriesImported,
                                   summary.weightEntriesImported,
                                   summary.notesImported)
            showingAlert = true
        }
    }
    
    private func showError(_ error: Error) {
        alertTitle = "common.error".localized
        alertMessage = error.localizedDescription
        showingAlert = true
    }
    
    private func shareFile(_ url: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootViewController.view
            popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        rootViewController.present(activityVC, animated: true)
    }
}

struct ExportOptionsView: View {
    @ObservedObject var viewModel: ImportExportViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var includePhotos = true
    @State private var includeVideos = true
    @State private var includeSettings = true
    @State private var includeWeightData = true
    @State private var includeNotes = true
    @State private var useDateRange = false
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var selectedCategories = Set<String>()
    
    var body: some View {
        NavigationView {
            Form {
                Section("import_export.data_types".localized) {
                    Toggle("import_export.photos".localized, isOn: $includePhotos)
                    Toggle("import_export.videos".localized, isOn: $includeVideos)
                    Toggle("import_export.weight_data".localized, isOn: $includeWeightData)
                    Toggle("import_export.notes".localized, isOn: $includeNotes)
                    Toggle("import_export.settings".localized, isOn: $includeSettings)
                }
                
                Section("import_export.period".localized) {
                    Toggle("import_export.specify_period".localized, isOn: $useDateRange)
                    
                    if useDateRange {
                        DatePicker("import_export.start_date".localized, selection: $startDate, displayedComponents: .date)
                        DatePicker("import_export.end_date".localized, selection: $endDate, displayedComponents: .date)
                    }
                }
                
                if includePhotos {
                    Section("import_export.categories".localized) {
                        let categories = CategoryStorageService.shared.getActiveCategories()
                        
                        if categories.count > 1 {
                            ForEach(categories) { category in
                                HStack {
                                    Text(category.name)
                                    Spacer()
                                    if selectedCategories.isEmpty || selectedCategories.contains(category.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.bodyLapseTurquoise)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    toggleCategory(category.id)
                                }
                            }
                            
                            Button("import_export.select_all".localized) {
                                selectedCategories.removeAll()
                            }
                            .font(.caption)
                        } else {
                            Text("import_export.single_category".localized)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("import_export.export_options".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("import_export.export".localized) {
                        startExport()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func toggleCategory(_ categoryId: String) {
        if selectedCategories.contains(categoryId) {
            selectedCategories.remove(categoryId)
        } else {
            selectedCategories.insert(categoryId)
        }
    }
    
    private func startExport() {
        let options = ImportExportService.ExportOptions(
            includePhotos: includePhotos,
            includeVideos: includeVideos,
            includeSettings: includeSettings,
            includeWeightData: includeWeightData,
            includeNotes: includeNotes,
            dateRange: useDateRange ? startDate...endDate : nil,
            categories: selectedCategories.isEmpty ? nil : Array(selectedCategories)
        )
        
        dismiss()
        viewModel.startExport(options: options)
    }
}
