import Foundation
import UIKit

class GuidelineStorageService {
    static let shared = GuidelineStorageService()
    
    private let guidelineKey = "BodyLapseGuideline"
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    func saveGuideline(_ guideline: BodyGuideline) {
        if let encoded = try? JSONEncoder().encode(guideline) {
            userDefaults.set(encoded, forKey: guidelineKey)
        }
    }
    
    func loadGuideline() -> BodyGuideline? {
        guard let data = userDefaults.data(forKey: guidelineKey),
              let guideline = try? JSONDecoder().decode(BodyGuideline.self, from: data) else {
            return nil
        }
        return guideline
    }
    
    func deleteGuideline() {
        userDefaults.removeObject(forKey: guidelineKey)
    }
    
    func hasGuideline() -> Bool {
        return loadGuideline() != nil
    }
}