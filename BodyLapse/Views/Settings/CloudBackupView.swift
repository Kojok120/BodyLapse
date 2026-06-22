import SwiftUI

/// Pro限定のクラウドバックアップ画面。iCloudへのバックアップ/復元を行う。
struct CloudBackupView: View {
    @StateObject private var service = CloudBackupService.shared
    @State private var showingRestoreConfirm = false

    private var isWorking: Bool {
        if case .working = service.state { return true }
        return false
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("cloud.last_backup".localized)
                    Spacer()
                    if let date = service.lastBackupDate {
                        Text(date, style: .date)
                            .foregroundColor(.secondary)
                    } else {
                        Text("cloud.never".localized)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section {
                Button {
                    Task { await service.backupNow() }
                } label: {
                    Label("cloud.backup_now".localized, systemImage: "icloud.and.arrow.up")
                }
                .disabled(isWorking)

                Button {
                    showingRestoreConfirm = true
                } label: {
                    Label("cloud.restore".localized, systemImage: "icloud.and.arrow.down")
                }
                .disabled(isWorking)
            } footer: {
                Text("cloud.footer".localized)
            }

            if isWorking {
                Section {
                    HStack {
                        ProgressView()
                        Text("common.processing".localized)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("cloud.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await service.refreshLastBackupDate()
        }
        .alert("cloud.restore_title".localized, isPresented: $showingRestoreConfirm) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("cloud.restore".localized) {
                Task { await service.restoreFromCloud() }
            }
        } message: {
            Text("cloud.restore_confirm".localized)
        }
        .alert("cloud.title".localized, isPresented: successBinding) {
            Button("common.ok".localized) { service.state = .idle }
        } message: {
            Text("cloud.success".localized)
        }
        .alert("common.error".localized, isPresented: errorBinding) {
            Button("common.ok".localized) { service.state = .idle }
        } message: {
            Text(errorMessage)
        }
    }

    private var successBinding: Binding<Bool> {
        Binding(
            get: { service.state == .success },
            set: { _ in service.state = .idle }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { if case .failure = service.state { return true } else { return false } },
            set: { _ in service.state = .idle }
        )
    }

    private var errorMessage: String {
        if case .failure(let message) = service.state { return message }
        return ""
    }
}
