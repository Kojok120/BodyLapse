import Foundation

// iOS用のシンプルなファイルアーカイブ実装
// 注意: iOSには外部ライブラリなしのネイティブZIPサポートがないため、
// カスタム.bodylapseアーカイブ形式を作成します
class SimpleZipArchive {
    private static let chunkSize = 1_048_576 // 1MB
    private static let maxPathLength = 8_192
    private static let magic = "BODY".data(using: .utf8)!

    private enum ArchiveError: Error {
        case unexpectedEOF
        case invalidHeader
        case invalidPath
        case invalidLength
    }
    
    static func createZipFile(
        atPath zipPath: String,
        withContentsOfDirectory directory: String,
        keepParentDirectory: Bool = false
    ) -> Bool {
        do {
            let fileManager = FileManager.default
            let directoryURL = URL(fileURLWithPath: directory)
            let zipURL = URL(fileURLWithPath: zipPath)

            if fileManager.fileExists(atPath: zipURL.path) {
                try fileManager.removeItem(at: zipURL)
            }
            _ = fileManager.createFile(atPath: zipURL.path, contents: nil)

            let outputHandle = try FileHandle(forWritingTo: zipURL)
            defer { try? outputHandle.close() }

            let normalizedBasePath = directoryURL.standardizedFileURL.path.hasSuffix("/")
                ? directoryURL.standardizedFileURL.path
                : directoryURL.standardizedFileURL.path + "/"
            let parentPrefix = keepParentDirectory ? directoryURL.lastPathComponent + "/" : ""
            let enumerator = fileManager.enumerator(
                at: directoryURL,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )

            var files: [(url: URL, path: String, size: UInt64)] = []

            while let fileURL = enumerator?.nextObject() as? URL {
                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard values.isRegularFile == true else { continue }

                guard fileURL.path.hasPrefix(normalizedBasePath) else {
                    throw ArchiveError.invalidPath
                }
                var relativePath = String(fileURL.path.dropFirst(normalizedBasePath.count))
                if !parentPrefix.isEmpty {
                    relativePath = parentPrefix + relativePath
                }

                guard let safePath = sanitizedRelativePath(relativePath) else {
                    throw ArchiveError.invalidPath
                }

                guard let size = values.fileSize, size >= 0 else {
                    throw ArchiveError.invalidLength
                }

                files.append((url: fileURL, path: safePath, size: UInt64(size)))
            }

            try outputHandle.write(contentsOf: magic)
            try write(UInt16(1), to: outputHandle)
            guard files.count <= Int(UInt32.max) else {
                throw ArchiveError.invalidLength
            }
            try write(UInt32(files.count), to: outputHandle)

            for file in files {
                guard let pathData = file.path.data(using: .utf8) else {
                    throw ArchiveError.invalidPath
                }

                try write(UInt32(pathData.count), to: outputHandle)
                try outputHandle.write(contentsOf: pathData)
                try write(file.size, to: outputHandle)

                let inputHandle = try FileHandle(forReadingFrom: file.url)
                defer { try? inputHandle.close() }

                try copyBytes(count: file.size, from: inputHandle, to: outputHandle)
            }

            return true
        } catch {
            print("Error creating archive: \(error)")
            return false
        }
    }
    
    static func unzipFile(
        atPath zipPath: String,
        toDestination destination: String
    ) -> Bool {
        do {
            let fileManager = FileManager.default
            let zipURL = URL(fileURLWithPath: zipPath)
            let destinationRootURL = URL(fileURLWithPath: destination)

            try fileManager.createDirectory(at: destinationRootURL, withIntermediateDirectories: true)

            let archiveHandle = try FileHandle(forReadingFrom: zipURL)
            defer { try? archiveHandle.close() }

            let magicData = try readExact(magic.count, from: archiveHandle)
            guard magicData == magic else {
                throw ArchiveError.invalidHeader
            }

            let version = try readUInt16(from: archiveHandle)
            guard version == 1 else {
                throw ArchiveError.invalidHeader
            }

            let fileCount = try readUInt32(from: archiveHandle)

            for _ in 0..<fileCount {
                let pathLength = try readUInt32(from: archiveHandle)
                guard pathLength > 0, pathLength <= UInt32(maxPathLength) else {
                    throw ArchiveError.invalidPath
                }

                let pathData = try readExact(Int(pathLength), from: archiveHandle)
                guard let rawPath = String(data: pathData, encoding: .utf8),
                      let safePath = sanitizedRelativePath(rawPath),
                      let fileURL = destinationURL(for: safePath, under: destinationRootURL) else {
                    throw ArchiveError.invalidPath
                }

                let dataLength = try readUInt64(from: archiveHandle)

                try fileManager.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                if fileManager.fileExists(atPath: fileURL.path) {
                    try fileManager.removeItem(at: fileURL)
                }
                _ = fileManager.createFile(atPath: fileURL.path, contents: nil)

                let outputHandle = try FileHandle(forWritingTo: fileURL)
                do {
                    try copyBytes(count: dataLength, from: archiveHandle, to: outputHandle)
                    try outputHandle.close()
                } catch {
                    try? outputHandle.close()
                    try? fileManager.removeItem(at: fileURL)
                    throw error
                }
            }

            return true
        } catch {
            print("Error extracting archive: \(error)")
            return false
        }
    }

    // MARK: - バイナリIOヘルパー

    private static func write(_ value: UInt16, to handle: FileHandle) throws {
        var little = value.littleEndian
        let data = withUnsafeBytes(of: &little) { Data($0) }
        try handle.write(contentsOf: data)
    }

    private static func write(_ value: UInt32, to handle: FileHandle) throws {
        var little = value.littleEndian
        let data = withUnsafeBytes(of: &little) { Data($0) }
        try handle.write(contentsOf: data)
    }

    private static func write(_ value: UInt64, to handle: FileHandle) throws {
        var little = value.littleEndian
        let data = withUnsafeBytes(of: &little) { Data($0) }
        try handle.write(contentsOf: data)
    }

    private static func readExact(_ count: Int, from handle: FileHandle) throws -> Data {
        var data = Data()
        data.reserveCapacity(count)

        while data.count < count {
            let remaining = count - data.count
            guard let chunk = try handle.read(upToCount: remaining), !chunk.isEmpty else {
                throw ArchiveError.unexpectedEOF
            }
            data.append(chunk)
        }

        return data
    }

    private static func readUInt16(from handle: FileHandle) throws -> UInt16 {
        let data = try readExact(2, from: handle)
        return UInt16(data[0]) | (UInt16(data[1]) << 8)
    }

    private static func readUInt32(from handle: FileHandle) throws -> UInt32 {
        let data = try readExact(4, from: handle)
        return UInt32(data[0]) |
            (UInt32(data[1]) << 8) |
            (UInt32(data[2]) << 16) |
            (UInt32(data[3]) << 24)
    }

    private static func readUInt64(from handle: FileHandle) throws -> UInt64 {
        let data = try readExact(8, from: handle)
        return UInt64(data[0]) |
            (UInt64(data[1]) << 8) |
            (UInt64(data[2]) << 16) |
            (UInt64(data[3]) << 24) |
            (UInt64(data[4]) << 32) |
            (UInt64(data[5]) << 40) |
            (UInt64(data[6]) << 48) |
            (UInt64(data[7]) << 56)
    }

    private static func copyBytes(count: UInt64, from input: FileHandle, to output: FileHandle) throws {
        var remaining = count
        while remaining > 0 {
            let readSize = Int(min(UInt64(chunkSize), remaining))
            let chunk = try readExact(readSize, from: input)
            try output.write(contentsOf: chunk)
            remaining -= UInt64(chunk.count)
        }
    }

    // MARK: - パス検証

    private static func sanitizedRelativePath(_ path: String) -> String? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.hasPrefix("/") else { return nil }

        let components = normalized.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty else { return nil }
        guard !components.contains(where: { $0 == ".." || $0 == "." || $0.isEmpty }) else {
            return nil
        }

        return components.joined(separator: "/")
    }

    private static func destinationURL(for relativePath: String, under destinationRoot: URL) -> URL? {
        let root = destinationRoot.standardizedFileURL.resolvingSymlinksInPath()
        let candidate = root.appendingPathComponent(relativePath).standardizedFileURL.resolvingSymlinksInPath()

        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard candidate.path.hasPrefix(rootPath) else {
            return nil
        }
        return candidate
    }
}
