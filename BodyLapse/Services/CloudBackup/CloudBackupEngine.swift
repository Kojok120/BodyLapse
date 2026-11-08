import Foundation

enum CloudBackupError: Error, Equatable {
    /// クラウドに別のバックアップがあるので、選んでもらうまで上げない
    case needsDecision(CloudBackupPlanner.Decision.Reason)
    /// 上げている間に別の端末が目録を書き換えた
    case conflict
    case noBackup
    case invalidBackup
}

/// バックアップと復元の手順。CloudKit (CloudBackupStore) と書き出しの形式 (ArchiveEntry) の間をつなぐ。
/// 画面やシングルトンに触れないので、メモリ上の置き場で往復のテストができる
struct CloudBackupEngine {
    let store: CloudBackupStore
    var fileManager: FileManager = .default

    struct BackupOutcome: Equatable {
        let state: CloudBackupPlanner.LocalState
        let uploadedCount: Int
        let deletedCount: Int
    }

    struct RestoreOutcome {
        /// 書き出しの形式に展開したフォルダ (取り込みに渡す)
        let extractedDirectory: URL
        let state: CloudBackupPlanner.LocalState
        /// クラウドに見つからなかった写真・動画の数
        let missingMediaCount: Int
    }

    /// 書き出しの中身 (entries) をクラウドへ上げる。写真・動画 (.file) はまだ上げていない分だけを上げ、
    /// それ以外 (.data) は目録の zip にまとめる。
    /// - Parameter persist: 途中経過を保存する (止まっても次は続きから上げる)
    func backup(
        entries: [SimpleZipArchive.ArchiveEntry],
        local: CloudBackupPlanner.LocalState,
        localEarliestPhotoDate: Date?,
        force: Bool,
        now: Date = Date(),
        workDirectory: URL,
        persist: @MainActor (CloudBackupPlanner.LocalState) -> Void
    ) async throws -> BackupOutcome {
        try await store.prepare()
        let snapshot = try await store.fetchSnapshot()

        if case .needsDecision(let reason) = CloudBackupPlanner.decide(
            cloud: snapshot,
            local: local,
            localEarliestPhotoDate: localEarliestPhotoDate,
            force: force
        ) {
            throw CloudBackupError.needsDecision(reason)
        }

        var state = local
        if let cloudTag = snapshot.manifestTag, cloudTag != state.manifestTag {
            // 置き換えを選んだ: いまクラウドにある目録の写真・動画を引き継ぐ (上げ直しと消し漏れを防ぐ)
            let previous = try await downloadIndex(workDirectory: workDirectory).index.media
            state.media = previous
            state.uploadedRecordNames = Set(previous.map(\.recordName))
        } else if snapshot.manifestTag == nil {
            // 目録がまだ無い (初回の途中) か、iCloud 側で消された: 上げたつもりのものが本当にあるか確かめる
            let claimed = Array(state.uploadedRecordNames.union(state.media.map(\.recordName)))
            let existing = claimed.isEmpty ? [] : try await store.existingMediaRecordNames(among: claimed)
            state.uploadedRecordNames = existing
            state.media = state.media.filter { existing.contains($0.recordName) }
        }

        // 写真・動画と、それ以外に分ける
        var media: [CloudBackupPlanner.MediaItem] = []
        var mediaFiles: [String: URL] = [:]
        var dataEntries: [SimpleZipArchive.ArchiveEntry] = []
        for entry in entries {
            switch entry.source {
            case .file(let url):
                let size = (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                let item = CloudBackupPlanner.MediaItem(
                    path: entry.path,
                    recordName: CloudBackupPlanner.recordName(forMediaPath: entry.path),
                    size: size
                )
                media.append(item)
                mediaFiles[item.recordName] = url
            case .data:
                dataEntries.append(entry)
            }
        }

        // まだ上げていない分だけを上げる
        let alreadyUploaded = state.uploadedRecordNames.union(state.media.map(\.recordName))
        let toUpload = CloudBackupPlanner.mediaToUpload(current: media, alreadyUploaded: alreadyUploaded)
        for batch in toUpload.chunked(into: 8) {
            try await store.uploadMedia(batch.compactMap { item in
                mediaFiles[item.recordName].map { (recordName: item.recordName, fileURL: $0) }
            })
            state.uploadedRecordNames.formUnion(batch.map(\.recordName))
            await persist(state)
        }

        // 目録 (写真・動画の一覧と、小さなデータ) を保存する
        let index = CloudBackupPlanner.Index(formatVersion: CloudBackupPlanner.indexFormatVersion, createdAt: now, media: media)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let indexEntry = SimpleZipArchive.ArchiveEntry(path: CloudBackupPlanner.indexFileName, source: .data(try encoder.encode(index)))
        try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        let manifestURL = workDirectory.appendingPathComponent("manifest-\(UUID().uuidString).bodylapse")
        defer { try? fileManager.removeItem(at: manifestURL) }
        guard SimpleZipArchive.createArchive(atPath: manifestURL.path, entries: dataEntries + [indexEntry]) else {
            throw CloudBackupError.invalidBackup
        }

        let newTag: String
        do {
            newTag = try await store.saveManifest(fileURL: manifestURL, createdAt: now, expectedTag: snapshot.manifestTag)
        } catch CloudBackupStoreError.manifestChanged {
            throw CloudBackupError.conflict
        }

        // 目録が指さなくなった写真・動画を消す (目録の保存に成功してから。失敗しても次の回に消す)
        let currentNames = Set(media.map(\.recordName))
        let stale = Array(state.uploadedRecordNames.union(state.media.map(\.recordName)).subtracting(currentNames)).sorted()
        var deletedCount = 0
        if !stale.isEmpty, (try? await store.deleteMedia(recordNames: stale)) != nil {
            deletedCount = stale.count
        }
        // 旧形式は新形式で上げ終えたら消す (同じ中身を二重に持たない)
        if snapshot.legacyBackupDate != nil {
            try? await store.deleteLegacy()
        }

        state.manifestTag = newTag
        state.media = media
        state.uploadedRecordNames = deletedCount == stale.count ? currentNames : currentNames.union(stale)
        state.acknowledgedLegacyBackupDate = nil
        await persist(state)
        return BackupOutcome(state: state, uploadedCount: toUpload.count, deletedCount: deletedCount)
    }

    /// クラウドのバックアップを、書き出しの形式のフォルダとして workDirectory に展開する
    func restore(local: CloudBackupPlanner.LocalState, workDirectory: URL) async throws -> RestoreOutcome {
        let snapshot = try await store.fetchSnapshot()
        try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        let extracted = workDirectory.appendingPathComponent("extracted", isDirectory: true)
        try? fileManager.removeItem(at: extracted)

        if snapshot.manifestTag != nil {
            let (index, tag) = try await downloadIndex(workDirectory: workDirectory, extractTo: extracted)
            var downloads: [(recordName: String, destination: URL)] = []
            for item in index.media {
                guard let destination = SimpleZipArchive.safeDestinationURL(forRelativePath: item.path, under: extracted) else {
                    continue
                }
                downloads.append((recordName: item.recordName, destination: destination))
            }
            let missing = try await store.downloadMedia(downloads)
            var state = local
            state.manifestTag = tag
            state.media = index.media
            state.uploadedRecordNames = Set(index.media.map(\.recordName))
            state.acknowledgedLegacyBackupDate = nil
            return RestoreOutcome(extractedDirectory: extracted, state: state, missingMediaCount: missing.count + (index.media.count - downloads.count))
        }

        if let legacyDate = snapshot.legacyBackupDate {
            let zipURL = workDirectory.appendingPathComponent("legacy.bodylapse")
            defer { try? fileManager.removeItem(at: zipURL) }
            try await store.downloadLegacy(to: zipURL)
            guard SimpleZipArchive.unzipFile(atPath: zipURL.path, toDestination: extracted.path) else {
                throw CloudBackupError.invalidBackup
            }
            var state = local
            state.acknowledgedLegacyBackupDate = legacyDate
            return RestoreOutcome(extractedDirectory: extracted, state: state, missingMediaCount: 0)
        }

        throw CloudBackupError.noBackup
    }

    /// 目録を落として展開し、写真・動画の一覧を読む
    private func downloadIndex(workDirectory: URL, extractTo: URL? = nil) async throws -> (index: CloudBackupPlanner.Index, tag: String) {
        try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        let zipURL = workDirectory.appendingPathComponent("manifest-download-\(UUID().uuidString).bodylapse")
        defer { try? fileManager.removeItem(at: zipURL) }
        let tag = try await store.downloadManifest(to: zipURL)

        let destination = extractTo ?? workDirectory.appendingPathComponent("manifest-\(UUID().uuidString)", isDirectory: true)
        defer {
            if extractTo == nil { try? fileManager.removeItem(at: destination) }
        }
        guard SimpleZipArchive.unzipFile(atPath: zipURL.path, toDestination: destination.path) else {
            throw CloudBackupError.invalidBackup
        }
        let data = try Data(contentsOf: destination.appendingPathComponent(CloudBackupPlanner.indexFileName))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let index = try decoder.decode(CloudBackupPlanner.Index.self, from: data)
        guard index.formatVersion <= CloudBackupPlanner.indexFormatVersion else {
            throw CloudBackupError.invalidBackup
        }
        return (index, tag)
    }
}
