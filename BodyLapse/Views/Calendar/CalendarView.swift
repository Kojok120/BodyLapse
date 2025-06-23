import SwiftUI

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var selectedPhoto: Photo?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    CalendarHeaderView(currentMonth: viewModel.currentMonth)
                        .padding(.horizontal)
                    
                    CalendarGridView(
                        month: viewModel.currentMonth,
                        photos: viewModel.photosForCurrentMonth,
                        onDateSelected: { date in
                            if let photo = viewModel.photo(for: date) {
                                selectedPhoto = photo
                            }
                        }
                    )
                    .padding(.horizontal)
                    
                    if !viewModel.photosForCurrentMonth.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Photos this month")
                                .font(.headline)
                                .padding(.horizontal)
                                .padding(.top, 20)
                            
                            PhotoListView(photos: viewModel.photosForCurrentMonth) { photo in
                                selectedPhoto = photo
                            }
                        }
                    }
                }
            }
            .navigationTitle("Progress Calendar")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { viewModel.previousMonth() }) {
                            Label("Previous Month", systemImage: "chevron.left")
                        }
                        Button(action: { viewModel.nextMonth() }) {
                            Label("Next Month", systemImage: "chevron.right")
                        }
                        Divider()
                        Button(action: { viewModel.goToToday() }) {
                            Label("Today", systemImage: "calendar")
                        }
                    } label: {
                        Image(systemName: "calendar")
                    }
                }
            }
        }
        .sheet(item: $selectedPhoto) { photo in
            PhotoDetailView(photo: photo)
        }
    }
}

struct CalendarHeaderView: View {
    let currentMonth: Date
    
    private var monthYearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 10) {
            Text(monthYearFormatter.string(from: currentMonth))
                .font(.title2)
                .fontWeight(.bold)
            
            HStack {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 10)
    }
}

struct CalendarGridView: View {
    let month: Date
    let photos: [Photo]
    let onDateSelected: (Date) -> Void
    
    private var days: [Date?] {
        guard let monthInterval = Calendar.current.dateInterval(of: .month, for: month) else {
            return []
        }
        
        let firstOfMonth = monthInterval.start
        let firstWeekday = Calendar.current.component(.weekday, from: firstOfMonth) - 1
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        
        let numberOfDays = Calendar.current.dateComponents([.day], from: monthInterval.start, to: monthInterval.end).day ?? 0
        
        for day in 0..<numberOfDays {
            if let date = Calendar.current.date(byAdding: .day, value: day, to: firstOfMonth) {
                days.append(date)
            }
        }
        
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                CalendarDayView(
                    date: date,
                    hasPhoto: date != nil ? hasPhoto(for: date!) : false,
                    isToday: date != nil ? Calendar.current.isDateInToday(date!) : false
                ) {
                    if let date = date {
                        onDateSelected(date)
                    }
                }
            }
        }
    }
    
    private func hasPhoto(for date: Date) -> Bool {
        photos.contains { photo in
            Calendar.current.isDate(photo.captureDate, inSameDayAs: date)
        }
    }
}

struct CalendarDayView: View {
    let date: Date?
    let hasPhoto: Bool
    let isToday: Bool
    let onTap: () -> Void
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderColor, lineWidth: isToday ? 2 : 0)
                    )
                
                if let date = date {
                    VStack(spacing: 2) {
                        Text(dayFormatter.string(from: date))
                            .font(.system(size: 14, weight: isToday ? .bold : .regular))
                            .foregroundColor(textColor)
                        
                        if hasPhoto {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .disabled(date == nil)
    }
    
    private var backgroundColor: Color {
        if date == nil {
            return Color.clear
        } else if hasPhoto {
            return Color.green.opacity(0.15)
        } else {
            return Color(UIColor.secondarySystemBackground)
        }
    }
    
    private var borderColor: Color {
        isToday ? .blue : .clear
    }
    
    private var textColor: Color {
        if date == nil {
            return .clear
        } else if isToday {
            return .blue
        } else {
            return .primary
        }
    }
}

struct PhotoListView: View {
    let photos: [Photo]
    let onPhotoTap: (Photo) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(photos) { photo in
                    PhotoThumbnailView(photo: photo) {
                        onPhotoTap(photo)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct PhotoThumbnailView: View {
    let photo: Photo
    let onTap: () -> Void
    @State private var image: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .frame(width: 80, height: 80)
                
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    ProgressView()
                }
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedImage = PhotoStorageService.shared.loadImage(for: photo)
            DispatchQueue.main.async {
                self.image = loadedImage
            }
        }
    }
}