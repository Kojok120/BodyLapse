import Foundation
import HealthKit

class HealthKitService {
    static let shared = HealthKitService()
    
    private let healthStore = HKHealthStore()
    
    private init() {}
    
    // MARK: - Health Data Types
    
    private var bodyMassType: HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: .bodyMass)!
    }
    
    private var bodyFatPercentageType: HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!
    }
    
    // MARK: - Authorization
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Health data is not available on this device"]))
            return
        }
        
        let typesToRead: Set<HKObjectType> = [bodyMassType, bodyFatPercentageType]
        let typesToWrite: Set<HKSampleType> = [bodyMassType, bodyFatPercentageType]
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
    
    func isAuthorized() -> Bool {
        let weightStatus = healthStore.authorizationStatus(for: bodyMassType)
        let bodyFatStatus = healthStore.authorizationStatus(for: bodyFatPercentageType)
        
        return weightStatus == .sharingAuthorized && bodyFatStatus == .sharingAuthorized
    }
    
    // MARK: - Read Data
    
    func fetchLatestWeight(completion: @escaping (Double?, Error?) -> Void) {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: bodyMassType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            let weight = samples?.first as? HKQuantitySample
            let weightInKg = weight?.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
            
            DispatchQueue.main.async {
                completion(weightInKg, nil)
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchLatestBodyFatPercentage(completion: @escaping (Double?, Error?) -> Void) {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: bodyFatPercentageType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            let bodyFat = samples?.first as? HKQuantitySample
            let percentage = bodyFat?.quantity.doubleValue(for: HKUnit.percent())
            
            DispatchQueue.main.async {
                // Convert from decimal (0.197) to percentage (19.7)
                completion(percentage != nil ? percentage! * 100 : nil, nil)
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchWeightData(from startDate: Date, to endDate: Date, completion: @escaping ([WeightEntry], Error?) -> Void) {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let query = HKSampleQuery(
            sampleType: bodyMassType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion([], error)
                }
                return
            }
            
            let weightSamples = samples as? [HKQuantitySample] ?? []
            var entries: [WeightEntry] = []
            
            // Group samples by date and get body fat for each date
            let calendar = Calendar.current
            let groupedSamples = Dictionary(grouping: weightSamples) { sample in
                calendar.startOfDay(for: sample.startDate)
            }
            
            let group = DispatchGroup()
            
            for (date, samples) in groupedSamples {
                guard let latestSample = samples.last else { continue }
                let weightInKg = latestSample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                
                group.enter()
                self.fetchBodyFatPercentage(for: date) { bodyFat in
                    let entry = WeightEntry(
                        date: date,
                        weight: weightInKg,
                        bodyFatPercentage: bodyFat
                    )
                    entries.append(entry)
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                completion(entries.sorted { $0.date < $1.date }, nil)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func fetchBodyFatPercentage(for date: Date, completion: @escaping (Double?) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: bodyFatPercentageType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, _ in
            let bodyFat = samples?.first as? HKQuantitySample
            let percentage = bodyFat?.quantity.doubleValue(for: HKUnit.percent())
            completion(percentage != nil ? percentage! * 100 : nil)
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Write Data
    
    func saveWeight(_ weight: Double, date: Date = Date(), completion: @escaping (Bool, Error?) -> Void) {
        let weightQuantity = HKQuantity(unit: HKUnit.gramUnit(with: .kilo), doubleValue: weight)
        let weightSample = HKQuantitySample(
            type: bodyMassType,
            quantity: weightQuantity,
            start: date,
            end: date
        )
        
        healthStore.save(weightSample) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
    
    func saveBodyFatPercentage(_ percentage: Double, date: Date = Date(), completion: @escaping (Bool, Error?) -> Void) {
        // Convert percentage (19.7) to decimal (0.197)
        let bodyFatQuantity = HKQuantity(unit: HKUnit.percent(), doubleValue: percentage / 100)
        let bodyFatSample = HKQuantitySample(
            type: bodyFatPercentageType,
            quantity: bodyFatQuantity,
            start: date,
            end: date
        )
        
        healthStore.save(bodyFatSample) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
    
    
    // MARK: - Sync
    
    func syncHealthDataToApp(completion: @escaping (Bool, Error?) -> Void) {
        Task { @MainActor in
            guard SubscriptionManagerService.shared.isPremium else {
                completion(false, NSError(domain: "HealthKit", code: 2, userInfo: [NSLocalizedDescriptionKey: "Health sync is only available for premium users"]))
                return
            }
            
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            
            fetchWeightData(from: thirtyDaysAgo, to: Date()) { entries, error in
                if let error = error {
                    completion(false, error)
                    return
                }
                
                // Save entries to WeightStorageService
                Task {
                    for entry in entries {
                        try? await WeightStorageService.shared.saveEntry(entry)
                    }
                    
                    await MainActor.run {
                        completion(true, nil)
                    }
                }
            }
        }
    }
}