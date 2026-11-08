import SwiftUI
import Combine

@MainActor
class CalendarViewModel: ObservableObject {
    @Published var photos: [Photo] = [] {
        didSet { statistics = Self.computeStatistics(from: photos) }
    }
    @Published var selectedCategory: PhotoCategory = PhotoCategory.defaultCategory
    @Published var availableCategories: [PhotoCategory] = []
    @Published var dailyNotes: [Date: DailyNote] = [:]

    /// 撮影習慣の統計。photos 変更時に一度だけ再計算してキャッシュする（毎参照のO(n)再計算を回避）。
    @Published private(set) var statistics: PhotoStatistics = .empty

    private static func computeStatistics(from photos: [Photo]) -> PhotoStatistics {
        let calendar = Calendar.current
        let days = Set(photos.map { calendar.startOfDay(for: $0.captureDate) })
        return PhotoStatistics.compute(from: days)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadCategories()
        loadPhotos()
        loadDailyNotes()
        
        // 60 秒ごとに無条件で読み直すのをやめ、変わりうる時だけ読み直す
        // (写真・カテゴリは各通知で、日付をまたいだときとアプリに戻ったときはストリークのために)
        NotificationCenter.default.publisher(for: Notification.Name("PhotosUpdated"))
            .merge(with: NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification))
            .merge(with: NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadPhotos()
                self?.loadCategories()
                self?.loadDailyNotes()
            }
            .store(in: &cancellables)
        
        // カテゴリー更新を監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCategoriesUpdated),
            name: Notification.Name("CategoriesUpdated"),
            object: nil
        )
        
        // ガイドライン更新を監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGuidelineUpdated),
            name: Notification.Name("GuidelineUpdated"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func loadPhotos() {
        photos = PhotoStorageService.shared.photos
    }
    
    func loadCategories() {
        availableCategories = CategoryStorageService.shared.getActiveCategories()
        if !availableCategories.contains(where: { $0.id == selectedCategory.id }) {
            selectedCategory = availableCategories.first ?? PhotoCategory.defaultCategory
        }
    }
    
    func allPhotosForDate(_ date: Date) -> [Photo] {
        photos.filter { photo in
            Calendar.current.isDate(photo.captureDate, inSameDayAs: date)
        }
    }
    
    func selectCategory(_ category: PhotoCategory) {
        selectedCategory = category
    }
    
    // MARK: - デイリーノート
    
    func loadDailyNotes() {
        Task {
            do {
                let notesArray = try await DailyNoteStorageService.shared.getAllNotes()
                await MainActor.run {
                    // 配列を日付をキーとした辞書に変換
                    var notesDict: [Date: DailyNote] = [:]
                    for note in notesArray {
                        let startOfDay = Calendar.current.startOfDay(for: note.date)
                        notesDict[startOfDay] = note
                    }
                    self.dailyNotes = notesDict
                }
            } catch {
                print("Failed to load daily notes: \(error)")
            }
        }
    }
    
    func note(for date: Date) -> DailyNote? {
        // dailyNotes は日の 0:00 をキーにしているので、全件を探さずに引く
        dailyNotes[Calendar.current.startOfDay(for: date)]
    }
    
    func saveNote(content: String, for date: Date) {
        Task {
            do {
                try await DailyNoteStorageService.shared.saveNote(for: date, content: content)
                // 更新データを取得するためノートを再読み込み
                let notesArray = try await DailyNoteStorageService.shared.getAllNotes()
                await MainActor.run {
                    // 配列を日付をキーとした辞書に変換
                    var notesDict: [Date: DailyNote] = [:]
                    for note in notesArray {
                        let startOfDay = Calendar.current.startOfDay(for: note.date)
                        notesDict[startOfDay] = note
                    }
                    self.dailyNotes = notesDict
                }
            } catch {
                print("Failed to save daily note: \(error)")
            }
        }
    }
    
    func deleteNote(for date: Date) {
        Task {
            do {
                try await DailyNoteStorageService.shared.deleteNote(for: date)
                await MainActor.run {
                    let calendar = Calendar.current
                    self.dailyNotes.removeValue(forKey: calendar.startOfDay(for: date))
                }
            } catch {
                print("Failed to delete daily note: \(error)")
            }
        }
    }
    
    // MARK: - 通知ハンドラー
    
    @objc private func handleCategoriesUpdated() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("CalendarViewModel: Received CategoriesUpdated notification")
            
            // カテゴリーを再読み込み
            self.loadCategories()
            
            // UIを強制更新
            self.objectWillChange.send()
        }
    }
    
    @objc private func handleGuidelineUpdated(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("CalendarViewModel: Received GuidelineUpdated notification")
            
            // ガイドラインがカテゴリー状態に影響する可能性があるため再読み込み
            self.loadCategories()
            
            // UIを強制更新
            self.objectWillChange.send()
        }
    }
}