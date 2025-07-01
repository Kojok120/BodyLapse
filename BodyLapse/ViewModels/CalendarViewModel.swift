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
        
        // Listen for category updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCategoriesUpdated),
            name: Notification.Name("CategoriesUpdated"),
            object: nil
        )
        
        // Listen for guideline updates
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
    
    // MARK: - Daily Notes
    
    func loadDailyNotes() {
        Task {
            do {
                let notesArray = try await DailyNoteStorageService.shared.getAllNotes()
                await MainActor.run {
                    // Convert array to dictionary keyed by date
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
                // Reload notes to get the updated data
                let notesArray = try await DailyNoteStorageService.shared.getAllNotes()
                await MainActor.run {
                    // Convert array to dictionary keyed by date
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
    
    // MARK: - Notification Handlers
    
    @objc private func handleCategoriesUpdated() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("CalendarViewModel: Received CategoriesUpdated notification")
            
            // Reload categories
            self.loadCategories()
            
            // Force UI update
            self.objectWillChange.send()
        }
    }
    
    @objc private func handleGuidelineUpdated(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("CalendarViewModel: Received GuidelineUpdated notification")
            
            // Reload categories in case guidelines affect category state
            self.loadCategories()
            
            // Force UI update
            self.objectWillChange.send()
        }
    }
}