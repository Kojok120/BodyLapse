import SwiftUI

struct CalendarPopupView: View {
    @Binding var selectedDate: Date
    let photos: [Photo]
    let onDateSelected: (Date) -> Void
    let minDate: Date?
    let maxDate: Date?
    let categoryId: String?
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayedMonth = Date()
    
    private var calendar: Calendar {
        Calendar.current
    }
    
    private var monthYearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }
    
    private var daysInMonth: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else {
            return []
        }
        
        let startOfMonth = monthInterval.start
        let startOfWeek = calendar.dateInterval(of: .weekOfMonth, for: startOfMonth)?.start ?? startOfMonth
        
        var days: [Date] = []
        var currentDate = startOfWeek
        
        // Get 6 weeks of days (42 days total)
        for _ in 0..<42 {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return days
    }
    
    private var weekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let firstWeekday = calendar.firstWeekday
        return Array(symbols[firstWeekday-1..<symbols.count] + symbols[0..<firstWeekday-1])
    }
    
    private func hasPhoto(for date: Date) -> Bool {
        photos.contains { photo in
            if let categoryId = categoryId {
                return photo.categoryId == categoryId && calendar.isDate(photo.captureDate, inSameDayAs: date)
            } else {
                return calendar.isDate(photo.captureDate, inSameDayAs: date)
            }
        }
    }
    
    private func isCurrentMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
    }
    
    private func isDateEnabled(_ date: Date) -> Bool {
        if let minDate = minDate, date < minDate {
            return false
        }
        if let maxDate = maxDate, date > maxDate {
            return false
        }
        return true
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Month navigation
                HStack {
                    Button(action: {
                        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Text(monthYearFormatter.string(from: displayedMonth))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: {
                        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal)
                
                // Weekday headers
                HStack(spacing: 0) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                
                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                    ForEach(daysInMonth, id: \.self) { date in
                        Button(action: {
                            onDateSelected(date)
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isCurrentMonth(date) ? Color(UIColor.systemBackground) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                calendar.isDate(date, inSameDayAs: selectedDate) ? Color.accentColor : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                                
                                VStack(spacing: 4) {
                                    Text("\(calendar.component(.day, from: date))")
                                        .font(.system(size: 16, weight: calendar.isDate(date, inSameDayAs: Date()) ? .bold : .regular))
                                        .foregroundColor(isCurrentMonth(date) && isDateEnabled(date) ? .primary : .secondary)
                                        .opacity(isDateEnabled(date) ? 1.0 : 0.3)
                                    
                                    if hasPhoto(for: date) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 6, height: 6)
                                            .opacity(isDateEnabled(date) ? 1.0 : 0.3)
                                    }
                                }
                            }
                            .frame(height: 45)
                        }
                        .disabled(!isCurrentMonth(date) || !isDateEnabled(date))
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Legend
                HStack(spacing: 20) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                        Text("Photo taken")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.accentColor, lineWidth: 2)
                            .frame(width: 16, height: 16)
                        Text("Selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom)
            }
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            displayedMonth = selectedDate
        }
    }
}

struct CalendarPopupView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarPopupView(
            selectedDate: .constant(Date()),
            photos: [],
            onDateSelected: { _ in },
            minDate: nil,
            maxDate: nil,
            categoryId: nil
        )
    }
}