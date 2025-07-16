import SwiftUI

// MARK: - Date Picker View

struct DatePickerView: View {
    @ObservedObject var viewModel: GalleryViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedMonth = Date()
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Month/Year selector
                monthYearSelector
                    .padding(.horizontal)
                    .padding(.top, 20)
                
                // Date chips grid
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 12)], spacing: 12) {
                        ForEach(datesInSelectedMonth(), id: \.self) { date in
                            DateChip(
                                date: date,
                                isSelected: viewModel.selectedDates.contains(where: { calendar.isDate($0, inSameDayAs: date) }),
                                hasPhotos: hasPhotosOnDate(date),
                                action: {
                                    viewModel.toggleDate(date)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("gallery.select_dates".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("gallery.clear_all".localized) {
                        viewModel.selectedDates.removeAll()
                    }
                    .disabled(viewModel.selectedDates.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var monthYearSelector: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundColor(.bodyLapseTurquoise)
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text(monthString)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(yearString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: nextMonth) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.bodyLapseTurquoise)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
    
    private func previousMonth() {
        selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
    }
    
    private func nextMonth() {
        selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
    }
    
    private var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: selectedMonth)
    }
    
    private var yearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: selectedMonth)
    }
    
    private func datesInSelectedMonth() -> [Date] {
        let startOfMonth = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? Date()
        let range = calendar.range(of: .day, in: .month, for: startOfMonth) ?? 1..<2
        
        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }
    
    private func hasPhotosOnDate(_ date: Date) -> Bool {
        return viewModel.photos.contains { photo in
            calendar.isDate(photo.captureDate, inSameDayAs: date)
        }
    }
}

// MARK: - Date Chip

struct DateChip: View {
    let date: Date
    let isSelected: Bool
    let hasPhotos: Bool
    let action: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                if hasPhotos {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.9) : Color.orange)
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 60, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.bodyLapseTurquoise : (hasPhotos ? Color(UIColor.tertiarySystemBackground) : Color(UIColor.systemGray5)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(calendar.isDateInToday(date) ? Color.bodyLapseTurquoise : Color.clear, lineWidth: 2)
            )
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .opacity(hasPhotos ? 1.0 : 0.6)
    }
}