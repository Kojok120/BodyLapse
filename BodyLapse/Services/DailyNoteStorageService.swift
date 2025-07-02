//
//  DailyNoteStorageService.swift
//  BodyLapse
//
//  Created by Anthropic on 2025/01/01.
//

import Foundation

actor DailyNoteStorageService {
    static let shared = DailyNoteStorageService()
    
    private let notesFileName = "daily_notes.json"
    
    private var documentsDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    private var notesDirectory: URL? {
        documentsDirectory?.appendingPathComponent("Notes")
    }
    
    private var notesFileURL: URL? {
        notesDirectory?.appendingPathComponent(notesFileName)
    }
    
    private var notesCache: [DailyNote] = []
    private var isLoaded = false
    
    private init() {
        Task {
            await createDirectoriesIfNeeded()
            await loadNotesIfNeeded()
        }
    }
    
    private func createDirectoriesIfNeeded() async {
        guard let notesDir = notesDirectory else { return }
        
        if !FileManager.default.fileExists(atPath: notesDir.path) {
            try? FileManager.default.createDirectory(at: notesDir, withIntermediateDirectories: true)
        }
    }
    
    private func loadNotesIfNeeded() async {
        guard !isLoaded else { return }
        
        notesCache = await loadNotesFromDisk()
        isLoaded = true
    }
    
    private func loadNotesFromDisk() async -> [DailyNote] {
        guard let url = notesFileURL,
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let notes = try? JSONDecoder().decode([DailyNote].self, from: data) else {
            return []
        }
        
        return notes
    }
    
    private func saveNotesToDisk() async throws {
        guard let url = notesFileURL else { return }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(notesCache)
        try data.write(to: url)
    }
    
    func saveNote(for date: Date, content: String) async throws {
        await loadNotesIfNeeded()
        
        let startOfDay = Calendar.current.startOfDay(for: date)
        
        if let existingIndex = notesCache.firstIndex(where: { $0.dateOnly == startOfDay }) {
            notesCache[existingIndex].updateContent(content)
        } else {
            let newNote = DailyNote.createNote(for: date, content: content)
            notesCache.append(newNote)
        }
        
        notesCache.sort { $0.date > $1.date }
        
        try await saveNotesToDisk()
    }
    
    func getNote(for date: Date) async -> DailyNote? {
        await loadNotesIfNeeded()
        
        let startOfDay = Calendar.current.startOfDay(for: date)
        return notesCache.first { $0.dateOnly == startOfDay }
    }
    
    func deleteNote(for date: Date) async throws {
        await loadNotesIfNeeded()
        
        let startOfDay = Calendar.current.startOfDay(for: date)
        notesCache.removeAll { $0.dateOnly == startOfDay }
        
        try await saveNotesToDisk()
    }
    
    func getAllNotes() async -> [DailyNote] {
        await loadNotesIfNeeded()
        return notesCache
    }
    
    func getNotes(for dateRange: ClosedRange<Date>) async -> [DailyNote] {
        await loadNotesIfNeeded()
        
        let startOfStartDate = Calendar.current.startOfDay(for: dateRange.lowerBound)
        let endOfEndDate = Calendar.current.startOfDay(for: dateRange.upperBound).addingTimeInterval(86400 - 1)
        
        return notesCache.filter { note in
            note.date >= startOfStartDate && note.date <= endOfEndDate
        }
    }
    
    func hasNote(for date: Date) async -> Bool {
        await loadNotesIfNeeded()
        
        let startOfDay = Calendar.current.startOfDay(for: date)
        return notesCache.contains { $0.dateOnly == startOfDay }
    }
    
    func updateNote(_ note: DailyNote) async throws {
        await loadNotesIfNeeded()
        
        if let index = notesCache.firstIndex(where: { $0.id == note.id }) {
            notesCache[index] = note
            try await saveNotesToDisk()
        }
    }
    
    func getNoteDates() async -> Set<Date> {
        await loadNotesIfNeeded()
        
        return Set(notesCache.map { $0.dateOnly })
    }
}