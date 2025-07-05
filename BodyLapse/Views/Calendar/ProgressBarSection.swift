import SwiftUI

struct ProgressBarSection: View {
    let dateRange: [Date]
    let viewModel: CalendarViewModel
    @Binding var selectedIndex: Int
    @Binding var selectedDate: Date
    @Binding var selectedChartDate: Date?
    
    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(UIColor.systemGray5))
                        .frame(height: 60)
                    
                    HStack(spacing: 0) {
                        ForEach(0..<dateRange.count, id: \.self) { index in
                            let date = dateRange[index]
                            let hasPhoto = viewModel.photos.contains { photo in
                                Calendar.current.isDate(photo.captureDate, inSameDayAs: date)
                            }
                            let hasNote = viewModel.note(for: date) != nil
                            
                            Rectangle()
                                .fill(hasPhoto ? Color.accentColor : Color.clear)
                                .frame(width: geometry.size.width / CGFloat(dateRange.count))
                                .overlay(
                                    Rectangle()
                                        .stroke(Color(UIColor.systemGray4), lineWidth: 0.5)
                                )
                                .overlay(
                                    // Memo indicator dot
                                    VStack {
                                        if hasNote {
                                            Circle()
                                                .fill(Color.bodyLapseTurquoise)
                                                .frame(width: 4, height: 4)
                                                .padding(.top, 4)
                                        }
                                        Spacer()
                                    }
                                )
                        }
                    }
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 3)
                        )
                        .position(
                            x: {
                                let segmentWidth = geometry.size.width / CGFloat(dateRange.count)
                                let centerX = segmentWidth * CGFloat(selectedIndex) + (segmentWidth / 2)
                                // Constrain position to keep circle fully visible
                                return max(10, min(geometry.size.width - 10, centerX))
                            }(),
                            y: 40
                        )
                }
                .frame(height: 60)
                .padding(.vertical, 10)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let totalWidth = geometry.size.width
                            let segmentWidth = totalWidth / CGFloat(dateRange.count)
                            let newIndex = Int((value.location.x / segmentWidth).rounded())
                            
                            if newIndex >= 0 && newIndex < dateRange.count {
                                selectedIndex = newIndex
                                selectedDate = dateRange[newIndex]
                                selectedChartDate = dateRange[newIndex]  // Sync chart selection
                            }
                        }
                )
                .onTapGesture { location in
                    let totalWidth = geometry.size.width
                    let segmentWidth = totalWidth / CGFloat(dateRange.count)
                    let newIndex = Int((location.x / segmentWidth).rounded())
                    
                    if newIndex >= 0 && newIndex < dateRange.count {
                        selectedIndex = newIndex
                        selectedDate = dateRange[newIndex]
                        selectedChartDate = dateRange[newIndex]  // Sync chart selection
                    }
                }
            }
            .frame(height: 80)
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}