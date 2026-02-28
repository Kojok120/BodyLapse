import SwiftUI
import Combine

@MainActor
class CalendarViewModel: ObservableObject {
    @Published var currentMonth = Date()
    @Published var photos: [Photo] = []
    @Published var selectedCategory: PhotoCategory = PhotoCategory.defaultCategory
    @Published var availableCategories: [PhotoCategory] = []
    @Published var dailyNotes: [Date: DailyNote] = [:]
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadCategories()
        loadPhotos()
        loadDailyNotes()
        
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
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
        let isPremium = SubscriptionManagerService.shared.isPremium
        availableCategories = CategoryStorageService.shared.getActiveCategoriesForUser(isPremium: isPremium)
        if !availableCategories.contains(where: { $0.id == selectedCategory.id }) {
            selectedCategory = availableCategories.first ?? PhotoCategory.defaultCategory
        }
    }
    
    var photosForCurrentMonth: [Photo] {
        photos.filter { photo in
            photo.categoryId == selectedCategory.id &&
            Calendar.current.isDate(photo.captureDate, equalTo: currentMonth, toGranularity: .month)
        }
    }
    
    func photo(for date: Date) -> Photo? {
        photos.first { photo in
            photo.categoryId == selectedCategory.id &&
            Calendar.current.isDate(photo.captureDate, inSameDayAs: date)
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
    
    func previousMonth() {
        withAnimation {
            currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }
    
    func nextMonth() {
        withAnimation {
            currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }
    
    func goToToday() {
        withAnimation {
            currentMonth = Date()
        }
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
        let calendar = Calendar.current
        return dailyNotes.values.first { note in
            calendar.isDate(note.date, inSameDayAs: date)
        }
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