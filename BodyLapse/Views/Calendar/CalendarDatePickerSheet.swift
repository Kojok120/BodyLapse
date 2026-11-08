import SwiftUI

struct CalendarDatePickerSheet: View {
    @Binding var selectedDate: Date
    @Binding var showingDatePicker: Bool
    
    let dateRange: [Date]
    /// 選べるいちばん古い日 (今の表示期間より前の記録の日も選べる)
    let earliestSelectableDate: Date
    let photoDates: Set<Date>
    let dataDates: Set<Date>
    
    /// 選んだ日。表示期間の外なら、呼び出し側が期間を広げる
    let onDateSelected: (Date) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("calendar.select_date".localized)
                    .font(.headline)
                    .padding(.top, 20)
                
                // Legend
                VStack(spacing: 8) {
                    HStack(spacing: 20) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(red: 0, green: 0.7, blue: 0.8))
                                .frame(width: 8, height: 8)
                            Text("calendar.has_photo".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.bodyLapseYellow)
                                .frame(width: 8, height: 8)
                            Text("calendar.data_available".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("calendar.data_includes_note".localized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding(.horizontal)
                
                CustomDatePicker(
                    selection: Binding(
                        get: { selectedDate },
                        set: { newDate in
                            onDateSelected(newDate)
                            showingDatePicker = false
                        }
                    ),
                    dateRange: earliestSelectableDate...(dateRange.last ?? Date()),
                    photoDates: photoDates,
                    dataDates: dataDates
                )
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("calendar.select_date".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        showingDatePicker = false
                    }
                }
            }
        }
    }
}