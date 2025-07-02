import Foundation

// Simple file archive implementation for iOS
// Note: This creates a custom .bodylapse archive format since iOS doesn't have
// native ZIP support without external libraries
class SimpleZipArchive {
    
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
            var version: UInt16 = 1
            archiveData.append(Data(bytes: &version, count: 2))
            
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
            var fileCount = UInt32(files.count)
            archiveData.append(Data(bytes: &fileCount, count: 4))
            
            // Write each file
            for file in files {
                // Path length and path
                var pathLength = UInt32(file.path.count)
                archiveData.append(Data(bytes: &pathLength, count: 4))
                archiveData.append(file.path.data(using: .utf8)!)
                
                // Data length and data
                var dataLength = UInt64(file.data.count)
                archiveData.append(Data(bytes: &dataLength, count: 8))
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
            
            // Read archive data
            let archiveData = try Data(contentsOf: zipURL)
            var offset = 0
            
            // Check magic number
            guard offset + 4 <= archiveData.count else { return false }
            let magicData = archiveData.subdata(in: offset..<offset+4)
            guard String(data: magicData, encoding: .utf8) == "BODY" else { return false }
            offset += 4
            
            // Read version
            guard offset + 2 <= archiveData.count else { return false }
            let version = archiveData.withUnsafeBytes { bytes in
                bytes.load(fromByteOffset: offset, as: UInt16.self)
            }
            guard version == 1 else { return false }
            offset += 2
            
            // Read file count
            guard offset + 4 <= archiveData.count else { return false }
            let fileCount = archiveData.withUnsafeBytes { bytes in
                bytes.load(fromByteOffset: offset, as: UInt32.self)
            }
            offset += 4
            
            // Read each file
            for _ in 0..<fileCount {
                // Read path length
                guard offset + 4 <= archiveData.count else { break }
                let pathLength = archiveData.withUnsafeBytes { bytes in
                    bytes.load(fromByteOffset: offset, as: UInt32.self)
                }
                offset += 4
                
                // Read path
                guard offset + Int(pathLength) <= archiveData.count else { break }
                let pathData = archiveData.subdata(in: offset..<(offset + Int(pathLength)))
                guard let path = String(data: pathData, encoding: .utf8) else { break }
                offset += Int(pathLength)
                
                // Read data length
                guard offset + 8 <= archiveData.count else { break }
                let dataLength = archiveData.withUnsafeBytes { bytes in
                    bytes.load(fromByteOffset: offset, as: UInt64.self)
                }
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