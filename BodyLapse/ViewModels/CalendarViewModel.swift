import SwiftUI
import Combine

class CalendarViewModel: ObservableObject {
    @Published var currentMonth = Date()
    @Published var photos: [Photo] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadPhotos()
        
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.loadPhotos()
            }
            .store(in: &cancellables)
    }
    
    func loadPhotos() {
        photos = PhotoStorageService.shared.photos
    }
    
    var photosForCurrentMonth: [Photo] {
        photos.filter { photo in
            Calendar.current.isDate(photo.captureDate, equalTo: currentMonth, toGranularity: .month)
        }
    }
    
    func photo(for date: Date) -> Photo? {
        photos.first { photo in
            Calendar.current.isDate(photo.captureDate, inSameDayAs: date)
        }
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
}