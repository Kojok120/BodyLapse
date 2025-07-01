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
        progressMessage = "エクスポートを準備中..."
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
        progressMessage = "インポートを準備中..."
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
                progressMessage = "写真を準備中..."
            } else if percentage < 60 {
                progressMessage = "動画を準備中..."
            } else if percentage < 90 {
                progressMessage = "データを圧縮中..."
            } else {
                progressMessage = "エクスポートを完了中..."
            }
        } else {
            if percentage < 20 {
                progressMessage = "ファイルを展開中..."
            } else if percentage < 50 {
                progressMessage = "写真をインポート中..."
            } else if percentage < 80 {
                progressMessage = "動画をインポート中..."
            } else {
                progressMessage = "インポートを完了中..."
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
                Section("インポートするデータ") {
                    Toggle("写真", isOn: $importPhotos)
                    Toggle("動画", isOn: $importVideos)
                    Toggle("体重・体脂肪率データ", isOn: $importWeightData)
                    Toggle("メモ", isOn: $importNotes)
                    Toggle("設定", isOn: $importSettings)
                }
                
                Section("重複データの処理") {
                    Picker("処理方法", selection: $mergeStrategy) {
                        Text("スキップ").tag(ImportExportService.ImportOptions.MergeStrategy.skip)
                        Text("置き換え").tag(ImportExportService.ImportOptions.MergeStrategy.replace)
                        Text("両方保持").tag(ImportExportService.ImportOptions.MergeStrategy.keepBoth)
                    }
                    
                    switch mergeStrategy {
                    case .skip:
                        Text("既存のデータはそのまま保持され、新しいデータのみ追加されます")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    case .replace:
                        Text("既存のデータが新しいデータで上書きされます")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    case .keepBoth:
                        Text("両方のデータが保持されます（写真・動画は別名で保存）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("インポートオプション")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("インポート") {
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