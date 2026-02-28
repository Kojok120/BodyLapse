import SwiftUI

struct DateSliderView: View {
    let entries: [WeightEntry]
    @Binding var selectedDate: Date?
    let onEditWeight: () -> Void
    let dateRange: ClosedRange<Date>?
    let onDateChange: (Date) -> Void
    
    @StateObject private var userSettings = UserSettingsManager.shared
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    private var sortedEntries: [WeightEntry] {
        entries.sorted { $0.date < $1.date }
    }
    
    private var selectedEntry: WeightEntry? {
        guard let selectedDate = selectedDate else { return nil }
        
        return sortedEntries.first { entry in
            Calendar.current.isDate(entry.date, inSameDayAs: selectedDate)
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if let selectedDate = selectedDate {
                HStack(spacing: 20) {
                    Text(formatDate(selectedDate))
                        .font(.subheadline)
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        if let selectedEntry = selectedEntry {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("chart.weight".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(convertedWeight(selectedEntry.weight), specifier: "%.1f") \(userSettings.settings.weightUnit.symbol)")
                                    .font(.body)
                                    .foregroundColor(.bodyLapseTurquoise)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(minWidth: 60)
                            
                            if let bodyFat = selectedEntry.bodyFatPercentage {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("chart.body_fat".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "weight.percentage_format".localized, bodyFat))
                                        .font(.body)
                                        .foregroundColor(.orange)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(minWidth: 60)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("chart.no_data".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("chart.tap_to_add".localized)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .frame(minWidth: 120)
                        }
                    }
                    
                    Button(action: onEditWeight) {
                        Image(systemName: selectedEntry != nil ? "pencil.circle.fill" : "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
                .offset(x: dragOffset)
                .scaleEffect(isDragging ? 0.98 : 1.0)
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: isDragging)
                .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            dragOffset = value.translation.width * 0.3 // Reduce sensitivity
                        }
                        .onEnded { value in
                            isDragging = false
                            let threshold: CGFloat = 50
                            
                            if value.translation.width > threshold {
                                // 右スワイプ - 前日へ
                                changeToPreviousDay()
                            } else if value.translation.width < -threshold {
                                // 左スワイプ - 翌日へ
                                changeToNextDay()
                            }
                            
                            // オフセットをリセット
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                )
            }
        }
    }
    
    private func changeToPreviousDay() {
        guard let currentDate = selectedDate else { return }
        
        let calendar = Calendar.current
        if let previousDay = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: currentDate)) {
            // 前日が許可範囲内か確認
            if let range = dateRange, range.contains(previousDay) {
                onDateChange(previousDay)
                triggerHapticFeedback()
            }
        }
    }
    
    private func changeToNextDay() {
        guard let currentDate = selectedDate else { return }
        
        let calendar = Calendar.current
        if let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: currentDate)) {
            // 翌日が許可範囲内で未来でないか確認
            let today = calendar.startOfDay(for: Date())
            if let range = dateRange, range.contains(nextDay) && nextDay <= today {
                onDateChange(nextDay)
                triggerHapticFeedback()
            }
        }
    }
    
    private func triggerHapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func convertedWeight(_ weight: Double) -> Double {
        userSettings.settings.weightUnit == .kg ? weight : weight * 2.20462
    }
    
    private static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        return formatter
    }()
    
    private func formatDate(_ date: Date) -> String {
        // 現在の言語を確認して適切なフォーマットを設定
        let currentLanguage = LanguageManager.shared.currentLanguage
        switch currentLanguage {
        case "ja":
            Self.dateFormatter.dateFormat = "yyyy/MM/dd"
        case "ko":
            Self.dateFormatter.dateFormat = "yyyy.MM.dd"
        default:
            Self.dateFormatter.dateFormat = "MMM d, yyyy"
        }
        
        return Self.dateFormatter.string(from: date)
    }
}

struct DateSliderView_Previews: PreviewProvider {
    static var previews: some View {
        DateSliderView(
            entries: [],
            selectedDate: .constant(Date()),
            onEditWeight: {},
            dateRange: Date()...Date(),
            onDateChange: { _ in }
        )
        .padding()
    }
}