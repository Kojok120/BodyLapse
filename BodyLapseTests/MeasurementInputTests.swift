import Foundation
import Testing
@testable import BodyLapse

struct MeasurementInputTests {

    @Test(arguments: [
        ("65.5", 65.5),
        ("65,5", 65.5),
        (" 65,5 ", 65.5),
        ("６５．５", 65.5),
        ("６５，５", 65.5),
        ("70", 70.0),
        ("70.", 70.0),
        (".5", 0.5)
    ])
    func testParseDecimalAcceptsDotAndComma(input: String, expected: Double) {
        #expect(MeasurementInput.parseDecimal(input) == expected)
    }

    @Test(arguments: ["", "  ", ".", ",", "65.5.1", "65,5,1", "1,234.5", "-65", "+65", "6e1", "abc", "65kg", "nan", "inf"])
    func testParseDecimalRejectsInvalidText(input: String) {
        #expect(MeasurementInput.parseDecimal(input) == nil)
    }

    @Test
    func testWeightKgConvertsPounds() throws {
        let kg = try #require(MeasurementInput.weightKg(from: "150,0", unit: .lbs))
        #expect(abs(kg - 150.0 / MeasurementInput.poundsPerKilogram) < 0.0001)
        #expect(MeasurementInput.weightKg(from: "65,5", unit: .kg) == 65.5)
    }

    @Test
    func testWeightKgRejectsOutOfRange() {
        #expect(MeasurementInput.weightKg(from: "0", unit: .kg) == nil)
        #expect(MeasurementInput.weightKg(from: "9.9", unit: .kg) == nil)
        #expect(MeasurementInput.weightKg(from: "501", unit: .kg) == nil)
        // 1200 lbs ≒ 544 kg
        #expect(MeasurementInput.weightKg(from: "1200", unit: .lbs) == nil)
        #expect(MeasurementInput.weightKg(from: "10", unit: .kg) == 10)
        #expect(MeasurementInput.weightKg(from: "500", unit: .kg) == 500)
    }

    @Test
    func testBodyFatRange() {
        #expect(MeasurementInput.bodyFat(from: "18,4") == 18.4)
        #expect(MeasurementInput.bodyFat(from: "0") == nil)
        #expect(MeasurementInput.bodyFat(from: "81") == nil)
        #expect(MeasurementInput.bodyFat(from: "x") == nil)
    }

    @Test
    func testInputTextUsesLocaleDecimalSeparator() {
        #expect(MeasurementInput.inputText(65.5, locale: Locale(identifier: "es_ES")) == "65,5")
        #expect(MeasurementInput.inputText(65.5, locale: Locale(identifier: "ja_JP")) == "65.5")
        #expect(MeasurementInput.inputText(1234.56, locale: Locale(identifier: "en_US")) == "1234.6")
    }

    @Test
    func testInputTextRoundTripsThroughParser() {
        for identifier in ["es_ES", "de_DE", "fr_FR", "ja_JP", "ko_KR", "en_CA"] {
            let text = MeasurementInput.inputText(72.3, locale: Locale(identifier: identifier))
            #expect(MeasurementInput.parseDecimal(text) == 72.3, "locale: \(identifier)")
        }
    }
}
