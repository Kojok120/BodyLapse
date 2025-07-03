import Foundation

// Simple file archive implementation for iOS
// Note: This creates a custom .bodylapse archive format since iOS doesn't have
// native ZIP support without external libraries
class SimpleZipArchive {
    
    // Helper methods for safe binary reading
    private static func readUInt16(from data: Data, at offset: Int) -> UInt16? {
        guard offset + 2 <= data.count else { return nil }
        var value: UInt16 = 0
        for i in 0..<2 {
            value |= UInt16(data[offset + i]) << (i * 8)
        }
        return value
    }
    
    private static func readUInt32(from data: Data, at offset: Int) -> UInt32? {
        guard offset + 4 <= data.count else { return nil }
        var value: UInt32 = 0
        for i in 0..<4 {
            value |= UInt32(data[offset + i]) << (i * 8)
        }
        return value
    }
    
    private static func readUInt64(from data: Data, at offset: Int) -> UInt64? {
        guard offset + 8 <= data.count else { return nil }
        var value: UInt64 = 0
        for i in 0..<8 {
            value |= UInt64(data[offset + i]) << (i * 8)
        }
        return value
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
            
            // Create a simple archive format:
            // [Magic Number][Version][File Count][Files...]
            // File format: [Path Length][Path][Data Length][Data]
            
            var archiveData = Data()
            
            // Magic number and version
            archiveData.append("BODY".data(using: .utf8)!) // Magic number
            let version: UInt16 = 1
            archiveData.append(contentsOf: withUnsafeBytes(of: version.littleEndian) { Array($0) })
            
            // Gather all files
            var files: [(path: String, data: Data)] = []
            let enumerator = fileManager.enumerator(at: directoryURL, includingPropertiesForKeys: [.isRegularFileKey])
            
            while let fileURL = enumerator?.nextObject() as? URL {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                
                if resourceValues.isRegularFile == true {
                    let relativePath = fileURL.path.replacingOccurrences(of: directory + "/", with: "")
                    let fileData = try Data(contentsOf: fileURL)
                    files.append((path: relativePath, data: fileData))
                }
            }
            
            // Write file count
            let fileCount = UInt32(files.count)
            archiveData.append(contentsOf: withUnsafeBytes(of: fileCount.littleEndian) { Array($0) })
            
            // Write each file
            for file in files {
                // Path length and path
                let pathLength = UInt32(file.path.count)
                archiveData.append(contentsOf: withUnsafeBytes(of: pathLength.littleEndian) { Array($0) })
                if let pathData = file.path.data(using: .utf8) {
                    archiveData.append(pathData)
                }
                
                // Data length and data
                let dataLength = UInt64(file.data.count)
                archiveData.append(contentsOf: withUnsafeBytes(of: dataLength.littleEndian) { Array($0) })
                archiveData.append(file.data)
            }
            
            // Write to file
            try archiveData.write(to: zipURL)
            
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
            let zipURL = URL(fileURLWithPath: zipPath)
            let destinationURL = URL(fileURLWithPath: destination)
            
            print("[SimpleZipArchive] Starting extraction from: \(zipPath)")
            
            // Read archive data
            let archiveData = try Data(contentsOf: zipURL)
            print("[SimpleZipArchive] Archive size: \(archiveData.count) bytes")
            var offset = 0
            
            // Check magic number
            print("[SimpleZipArchive] Checking magic number...")
            guard offset + 4 <= archiveData.count else { 
                print("[SimpleZipArchive] Not enough data for magic number")
                return false 
            }
            let magicData = archiveData.subdata(in: offset..<offset+4)
            guard String(data: magicData, encoding: .utf8) == "BODY" else { 
                print("[SimpleZipArchive] Invalid magic number")
                return false 
            }
            offset += 4
            
            // Read version
            print("[SimpleZipArchive] Reading version...")
            guard let version = readUInt16(from: archiveData, at: offset) else { 
                print("[SimpleZipArchive] Failed to read version")
                return false 
            }
            guard version == 1 else { 
                print("[SimpleZipArchive] Unsupported version: \(version)")
                return false 
            }
            offset += 2
            
            // Read file count
            print("[SimpleZipArchive] Reading file count...")
            guard let fileCount = readUInt32(from: archiveData, at: offset) else { 
                print("[SimpleZipArchive] Failed to read file count")
                return false 
            }
            print("[SimpleZipArchive] File count: \(fileCount)")
            offset += 4
            
            // Read each file
            for i in 0..<fileCount {
                print("[SimpleZipArchive] Processing file \(i+1)/\(fileCount)...")
                // Read path length
                guard let pathLength = readUInt32(from: archiveData, at: offset) else { break }
                offset += 4
                
                // Read path
                guard offset + Int(pathLength) <= archiveData.count else { break }
                let pathData = archiveData.subdata(in: offset..<(offset + Int(pathLength)))
                guard let path = String(data: pathData, encoding: .utf8) else { break }
                offset += Int(pathLength)
                
                // Read data length
                guard let dataLength = readUInt64(from: archiveData, at: offset) else { break }
                offset += 8
                
                // Read file data
                guard offset + Int(dataLength) <= archiveData.count else { break }
                let fileData = archiveData.subdata(in: offset..<(offset + Int(dataLength)))
                offset += Int(dataLength)
                
                // Write file
                let fileURL = destinationURL.appendingPathComponent(path)
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try fileData.write(to: fileURL)
            }
            
            return true
        } catch {
            print("Error extracting archive: \(error)")
            return false
        }
    }
}