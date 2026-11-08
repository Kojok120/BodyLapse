import Foundation
import Testing
@testable import BodyLapse

struct ComparePairingTests {

    private let base = Date(timeIntervalSince1970: 1_750_000_000)

    private func photo(day: Int, category: String = "default") -> Photo {
        Photo(captureDate: Calendar.current.date(byAdding: .day, value: day, to: base)!, fileName: "\(day).jpg", categoryId: category)
    }

    @Test
    func testDefaultPairUsesEarliestAndLatestInCategory() {
        let photos = [photo(day: 5), photo(day: 1), photo(day: 9), photo(day: 0, category: "side")]
        let pair = ComparePairing.defaultPair(from: photos, categoryId: "default")
        #expect(pair.before?.fileName == "1.jpg")
        #expect(pair.after?.fileName == "9.jpg")
    }

    @Test
    func testDefaultPairWithSinglePhotoFillsOnlyAfter() {
        let pair = ComparePairing.defaultPair(from: [photo(day: 3)], categoryId: "default")
        #expect(pair.before == nil)
        #expect(pair.after?.fileName == "3.jpg")
        #expect(ComparePairing.defaultPair(from: [], categoryId: "default").after == nil)
    }

    @Test
    func testPhotoOnDateMatchesCategory() {
        let photos = [photo(day: 2), photo(day: 2, category: "side")]
        let date = Calendar.current.date(byAdding: .day, value: 2, to: base)!
        #expect(ComparePairing.photo(on: date, categoryId: "side", in: photos)?.categoryId == "side")
        #expect(ComparePairing.photo(on: base, categoryId: "default", in: photos) == nil)
    }

    @Test
    func testDifference() {
        #expect(ComparePairing.difference(before: 70, after: 68.5) == -1.5)
        #expect(ComparePairing.difference(before: nil, after: 68.5) == nil)
    }
}
