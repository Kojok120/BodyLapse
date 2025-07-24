import SwiftUI

struct DataGraphSection: View {
    let selectedPeriod: TimePeriod
    let weightViewModel: WeightTrackingViewModel
    let dateRange: [Date]
    @Binding var selectedChartDate: Date?
    let onEditWeight: () -> Void
    
    var body: some View {
        VStack(spacing: 6) {
            if #available(iOS 16.0, *) {
                let filteredEntries = weightViewModel.filteredEntries(for: getWeightTimeRange())
                let fullRange: ClosedRange<Date> = {
                    if let first = dateRange.first, let last = dateRange.last {
                        return first...last
                    } else {
                        return Date()...Date()
                    }
                }()
                
                // Date slider with swipe functionality
                DateSliderView(
                    entries: filteredEntries,
                    selectedDate: $selectedChartDate,
                    onEditWeight: onEditWeight,
                    dateRange: fullRange,
                    onDateChange: { newDate in
                        selectedChartDate = newDate
                    }
                )
                .padding(.horizontal)
                
                // Weight chart view for premium users
                InteractiveWeightChartView(
                    entries: filteredEntries,
                    selectedDate: $selectedChartDate,
                    fullDateRange: fullRange
                )
                .padding(.horizontal)
                .onChange(of: selectedPeriod) { _, _ in
                    // Reset chart selection when period changes
                    selectedChartDate = nil
                }
            } else {
                Text("calendar.ios16_required".localized)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(15)
                    .padding(.horizontal)
            }
        }
    }
    
    private func getWeightTimeRange() -> WeightTimeRange {
        switch selectedPeriod {
        case .week: return .week
        case .month: return .month
        case .threeMonths: return .threeMonths
        case .sixMonths: return .threeMonths // Use 3 months as fallback
        case .year: return .year
        case .twoYears: return .all
        case .threeYears: return .all
        case .fiveYears: return .all
        }
    }
}