import Foundation
import Testing
import UIKit
import ImageIO
@testable import BodyLapse

struct PhotoImportEncodingTests {

    private func sampleImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 12))
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 12))
        }
    }

    @Test
    func testUprightJPEGIsKeptAsIs() throws {
        let jpeg = try #require(sampleImage().jpegData(compressionQuality: 0.9))
        let stored = try PhotoStorageService.storableJPEGData(fromImported: jpeg)
        #expect(stored == jpeg)
    }

    @Test
    func testPNGIsReencodedToJPEG() throws {
        let png = try #require(sampleImage().pngData())
        let stored = try PhotoStorageService.storableJPEGData(fromImported: png)
        let source = try #require(CGImageSourceCreateWithData(stored as CFData, nil))
        #expect(CGImageSourceGetType(source) as String? == "public.jpeg")
    }

    @Test
    func testGarbageIsRejected() {
        #expect(throws: (any Error).self) {
            try PhotoStorageService.storableJPEGData(fromImported: Data("not an image".utf8))
        }
    }
}
