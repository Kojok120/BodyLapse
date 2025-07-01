import Foundation
import SwiftUI

@MainActor
class ImportExportViewModel: ObservableObject {
    @Published var isExporting = false
    @Published var isImporting = false
    @Published var progress: Float = 0
    @Published var progressMessage = ""
    @Published var exportCompleted = false
    @Published var importCompleted = false
    @Published var error: Error?
    @Published var errorMessage: String?
    @Published var exportedFileURL: URL?
    @Published var importSummary: ImportExportService.ImportSummary?
    @Published var showingImportOptions = false
    
    private var pendingImportURL: URL?
    
    func startExport(options: ImportExportService.ExportOptions) {
        isExporting = true
        exportCompleted = false
        progress = 0
        progressMessage = "import.preparing_export".localized
        error = nil
        errorMessage = nil
        
        ImportExportService.shared.exportData(
            options: options,
            progress: { [weak self] progress in
                DispatchQueue.main.async {
                    self?.progress = progress
                    self?.updateProgressMessage(for: progress, isExporting: true)
                }
            },
            completion: { [weak self] result in
                DispatchQueue.main.async {
                    self?.isExporting = false
                    
                    switch result {
                    case .success(let url):
                        self?.exportedFileURL = url
                        self?.exportCompleted = true
                    case .failure(let error):
                        self?.error = error
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }
        )
    }
    
    func showImportOptions(for url: URL) {
        pendingImportURL = url
        showingImportOptions = true
    }
    
    func startImport(options: ImportExportService.ImportOptions) {
        guard let url = pendingImportURL else { return }
        
        isImporting = true
        importCompleted = false
        progress = 0
        progressMessage = "import.preparing_import".localized
        error = nil
        errorMessage = nil
        
        ImportExportService.shared.importData(
            from: url,
            options: options,
            progress: { [weak self] progress in
                DispatchQueue.main.async {
                    self?.progress = progress
                    self?.updateProgressMessage(for: progress, isExporting: false)
                }
            },
            completion: { [weak self] result in
                DispatchQueue.main.async {
                    self?.isImporting = false
                    
                    // Clean up temporary file
                    if let url = self?.pendingImportURL {
                        try? FileManager.default.removeItem(at: url)
                    }
                    self?.pendingImportURL = nil
                    
                    switch result {
                    case .success(let summary):
                        self?.importSummary = summary
                        self?.importCompleted = true
                    case .failure(let error):
                        self?.error = error
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }
        )
    }
    
    private func updateProgressMessage(for progress: Float, isExporting: Bool) {
        let percentage = Int(progress * 100)
        
        if isExporting {
            if percentage < 30 {
                progressMessage = "import.preparing_photos".localized
            } else if percentage < 60 {
                progressMessage = "import.preparing_videos".localized
            } else if percentage < 90 {
                progressMessage = "import.compressing_data".localized
            } else {
                progressMessage = "import.completing_export".localized
            }
        } else {
            if percentage < 20 {
                progressMessage = "import.extracting_files".localized
            } else if percentage < 50 {
                progressMessage = "import.importing_photos".localized
            } else if percentage < 80 {
                progressMessage = "import.importing_videos".localized
            } else {
                progressMessage = "import.completing_import".localized
            }
        }
    }
}

// Import Options Sheet
struct ImportOptionsSheet: View {
    @ObservedObject var viewModel: ImportExportViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var mergeStrategy: ImportExportService.ImportOptions.MergeStrategy = .skip
    @State private var importPhotos = true
    @State private var importVideos = true
    @State private var importSettings = false
    @State private var importWeightData = true
    @State private var importNotes = true
    
    var body: some View {
        NavigationView {
            Form {
                Section("import.data_to_import".localized) {
                    Toggle("import_export.photos".localized, isOn: $importPhotos)
                    Toggle("import_export.videos".localized, isOn: $importVideos)
                    Toggle("import_export.weight_data".localized, isOn: $importWeightData)
                    Toggle("import_export.notes".localized, isOn: $importNotes)
                    Toggle("import_export.settings".localized, isOn: $importSettings)
                }
                
                Section("import.duplicate_handling".localized) {
                    Picker("import.handling_method".localized, selection: $mergeStrategy) {
                        Text("import.skip".localized).tag(ImportExportService.ImportOptions.MergeStrategy.skip)
                        Text("import.replace".localized).tag(ImportExportService.ImportOptions.MergeStrategy.replace)
                        Text("import.keep_both".localized).tag(ImportExportService.ImportOptions.MergeStrategy.keepBoth)
                    }
                    
                    switch mergeStrategy {
                    case .skip:
                        Text("import.skip_description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    case .replace:
                        Text("import.replace_description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    case .keepBoth:
                        Text("import.keep_both_description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("import.import_options".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("import.import_button".localized) {
                        startImport()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func startImport() {
        let options = ImportExportService.ImportOptions(
            mergeStrategy: mergeStrategy,
            importPhotos: importPhotos,
            importVideos: importVideos,
            importSettings: importSettings,
            importWeightData: importWeightData,
            importNotes: importNotes
        )
        
        dismiss()
        viewModel.startImport(options: options)
    }
}