//
//  DailyNote.swift
//  BodyLapse
//
//  Created by Anthropic on 2025/01/01.
//

import Foundation

struct DailyNote: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    var content: String
    let createdDate: Date
    var lastModifiedDate: Date
    
    init(id: UUID = UUID(), date: Date, content: String, createdDate: Date = Date(), lastModifiedDate: Date = Date()) {
        self.id = id
        self.date = date
        self.content = content
        self.createdDate = createdDate
        self.lastModifiedDate = lastModifiedDate
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    var dateOnly: Date {
        Calendar.current.startOfDay(for: date)
    }
    
    var isEmpty: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    mutating func updateContent(_ newContent: String) {
        self.content = newContent
        self.lastModifiedDate = Date()
    }
}

extension DailyNote {
    static func createNote(for date: Date, content: String) -> DailyNote {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return DailyNote(date: startOfDay, content: content)
    }
}