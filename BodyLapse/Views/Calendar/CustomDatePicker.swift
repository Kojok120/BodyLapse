import SwiftUI
import UIKit

struct CustomDatePicker: UIViewRepresentable {
    @Binding var selection: Date
    let dateRange: ClosedRange<Date>
    let photoDates: Set<Date>
    let dataDates: Set<Date>
    
    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .inline
        picker.date = selection
        picker.minimumDate = dateRange.lowerBound
        picker.maximumDate = dateRange.upperBound
        
        picker.addTarget(context.coordinator, action: #selector(Coordinator.dateChanged(_:)), for: .valueChanged)
        
        // Customize the appearance
        DispatchQueue.main.async {
            self.addIndicators(to: picker)
        }
        
        return picker
    }
    
    func updateUIView(_ uiView: UIDatePicker, context: Context) {
        uiView.date = selection
        
        // Re-add indicators when view updates
        DispatchQueue.main.async {
            self.addIndicators(to: uiView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func addIndicators(to picker: UIDatePicker) {
        // Remove existing indicators
        picker.subviews.forEach { subview in
            subview.subviews.forEach { innerView in
                if innerView.tag == 999 {
                    innerView.removeFromSuperview()
                }
            }
        }
        
        // Find the calendar view
        guard let calendarView = findCalendarView(in: picker) else { return }
        
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d"
        
        // Add indicators for each visible date
        for subview in calendarView.subviews {
            findDateCells(in: subview) { cell, label in
                if let text = label.text,
                   let day = Int(text),
                   let cellDate = getDateForCell(day: day, in: picker) {
                    
                    let normalizedDate = calendar.startOfDay(for: cellDate)
                    let hasPhoto = photoDates.contains(normalizedDate)
                    let hasData = dataDates.contains(normalizedDate)
                    
                    if hasPhoto || hasData {
                        addIndicator(to: cell, hasPhoto: hasPhoto, hasData: hasData)
                    }
                }
            }
        }
    }
    
    private func findCalendarView(in view: UIView) -> UIView? {
        for subview in view.subviews {
            if String(describing: type(of: subview)).contains("Calendar") ||
               String(describing: type(of: subview)).contains("DatePicker") {
                return subview
            }
            if let found = findCalendarView(in: subview) {
                return found
            }
        }
        return nil
    }
    
    private func findDateCells(in view: UIView, completion: (UIView, UILabel) -> Void) {
        if let label = view as? UILabel {
            completion(view.superview ?? view, label)
        }
        
        for subview in view.subviews {
            findDateCells(in: subview, completion: completion)
        }
    }
    
    private func getDateForCell(day: Int, in picker: UIDatePicker) -> Date? {
        let calendar = Calendar.current
        let pickerComponents = calendar.dateComponents([.year, .month], from: picker.date)
        
        var components = DateComponents()
        components.year = pickerComponents.year
        components.month = pickerComponents.month
        components.day = day
        
        return calendar.date(from: components)
    }
    
    private func addIndicator(to cell: UIView, hasPhoto: Bool, hasData: Bool) {
        let indicatorSize: CGFloat = 6
        let spacing: CGFloat = 2
        
        let containerView = UIView()
        containerView.tag = 999
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.isUserInteractionEnabled = false
        
        var indicators: [UIView] = []
        
        if hasPhoto {
            let photoIndicator = UIView()
            photoIndicator.backgroundColor = UIColor(red: 0, green: 0.7, blue: 0.8, alpha: 1) // Turquoise
            photoIndicator.layer.cornerRadius = indicatorSize / 2
            photoIndicator.translatesAutoresizingMaskIntoConstraints = false
            indicators.append(photoIndicator)
        }
        
        if hasData {
            let dataIndicator = UIView()
            dataIndicator.backgroundColor = UIColor(red: 1, green: 0.82, blue: 0, alpha: 1) // Yellow
            dataIndicator.layer.cornerRadius = indicatorSize / 2
            dataIndicator.translatesAutoresizingMaskIntoConstraints = false
            indicators.append(dataIndicator)
        }
        
        cell.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
            containerView.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -2),
            containerView.heightAnchor.constraint(equalToConstant: indicatorSize)
        ])
        
        for (index, indicator) in indicators.enumerated() {
            containerView.addSubview(indicator)
            
            NSLayoutConstraint.activate([
                indicator.widthAnchor.constraint(equalToConstant: indicatorSize),
                indicator.heightAnchor.constraint(equalToConstant: indicatorSize),
                indicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
            ])
            
            if indicators.count == 1 {
                indicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor).isActive = true
            } else {
                let offset = CGFloat(index) * (indicatorSize + spacing) - (indicatorSize + spacing) / 2
                indicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor, constant: offset).isActive = true
            }
        }
        
        let totalWidth = CGFloat(indicators.count) * indicatorSize + CGFloat(indicators.count - 1) * spacing
        containerView.widthAnchor.constraint(equalToConstant: totalWidth).isActive = true
    }
    
    class Coordinator: NSObject {
        var parent: CustomDatePicker
        
        init(_ parent: CustomDatePicker) {
            self.parent = parent
        }
        
        @objc func dateChanged(_ sender: UIDatePicker) {
            parent.selection = sender.date
        }
    }
}