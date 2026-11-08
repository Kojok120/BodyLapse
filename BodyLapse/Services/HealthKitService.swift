import Foundation
import HealthKit

class HealthKitService {
    static let shared = HealthKitService()
    
    private let healthStore = HKHealthStore()
    
    private init() {}
    
    // MARK: - ヘルスデータタイプ
    
    private var bodyMassType: HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: .bodyMass)!
    }
    
    private var bodyFatPercentageType: HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!
    }
    
    // MARK: - 認証
    
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
        
        print("Weight authorization status: \(weightStatus.rawValue)")
        print("Body fat authorization status: \(bodyFatStatus.rawValue)")
        
        return weightStatus == .sharingAuthorized && bodyFatStatus == .sharingAuthorized
    }
    
    // MARK: - データ取得
    
    /// 期間内の量のサンプルを取る
    private func fetchSamples(of type: HKQuantityType, unit: HKUnit, from startDate: Date, to endDate: Date) async throws -> [HealthKitImportPlanner.Sample] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let values = (samples as? [HKQuantitySample] ?? []).map {
                    HealthKitImportPlanner.Sample(date: $0.startDate, value: $0.quantity.doubleValue(for: unit))
                }
                continuation.resume(returning: values)
            }
            healthStore.execute(query)
        }
    }

    /// 期間内の体重と体脂肪率を日ごとにまとめる。体脂肪率は日数分ではなく 1 回の問い合わせで取る
    private func fetchDailyMeasurements(from startDate: Date, to endDate: Date) async throws -> [HealthKitImportPlanner.DailyMeasurement] {
        async let weights = fetchSamples(of: bodyMassType, unit: .gramUnit(with: .kilo), from: startDate, to: endDate)
        // 体脂肪率は 0.197 のような小数で入っているので % に直す
        async let bodyFats = fetchSamples(of: bodyFatPercentageType, unit: .percent(), from: startDate, to: endDate)
        let fats = try await bodyFats.map { HealthKitImportPlanner.Sample(date: $0.date, value: $0.value * 100) }
        return HealthKitImportPlanner.dailyMeasurements(weights: try await weights, bodyFats: fats)
    }

    func fetchWeightData(from startDate: Date, to endDate: Date, completion: @escaping ([WeightEntry], Error?) -> Void) {
        Task {
            do {
                let entries = try await fetchDailyMeasurements(from: startDate, to: endDate).map {
                    WeightEntry(date: $0.day, weight: $0.weightKg, bodyFatPercentage: $0.bodyFatPercentage)
                }
                await MainActor.run { completion(entries, nil) }
            } catch {
                await MainActor.run { completion([], error) }
            }
        }
    }
    
    // MARK: - データ書き込み
    
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
        // パーセンテージ（19.7）から小数（0.197）に変換
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
    
    
    // MARK: - 同期
    
    /// ヘルスケアの記録をアプリの体重の記録へ取り込む。まとめて 1 回で書き、アプリで直した日・消した日は書き戻さない
    func syncHealthDataToApp(completion: @escaping (Bool, Error?) -> Void) {
        Task {
            do {
                // HealthKitから全利用可能なデータを取得（2024年8月1日から）
                let startDate = Calendar.current.date(from: DateComponents(year: 2024, month: 8, day: 1))!
                let measurements = try await fetchDailyMeasurements(from: startDate, to: Date())
                let storage = WeightStorageService.shared
                let toWrite = HealthKitImportPlanner.entriesToWrite(
                    measurements: measurements,
                    existing: try await storage.loadEntries(),
                    deletedDays: (try? await storage.deletedDays()) ?? [:],
                    dayKey: WeightStorageService.dayKey(for:)
                )
                if !toWrite.isEmpty {
                    _ = try await storage.mergeEntries(toWrite, strategy: .replaceExisting)
                }
                await MainActor.run {
                    if !toWrite.isEmpty {
                        NotificationCenter.default.post(name: Notification.Name("HealthKitDataSynced"), object: nil)
                    }
                    completion(true, nil)
                }
            } catch {
                await MainActor.run { completion(false, error) }
            }
        }
    }
}