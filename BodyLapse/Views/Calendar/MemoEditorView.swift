import SwiftUI

struct MemoEditorView: View {
    let date: Date
    let initialContent: String
    let onSave: (String) -> Void
    let onDelete: () -> Void
    
    @State private var memoText: String = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "note.text")
                            .font(.system(size: 50))
                            .foregroundColor(.accentColor)
                        
                        Text("memo.add_memo".localized)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(formatDate(date))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 30)
                    .padding(.bottom, 20)
                    
                    // Text editor
                    VStack(alignment: .leading, spacing: 8) {
                        Text("memo.content".localized)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                        
                        TextEditor(text: $memoText)
                            .font(.body)
                            .padding(8)
                            .frame(height: 150)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal)
                            .focused($isTextFieldFocused)
                            .scrollContentBackground(.hidden)
                            .onChange(of: memoText) { _, newValue in
                                if newValue.count > 100 {
                                    memoText = String(newValue.prefix(100))
                                }
                            }
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("common.done".localized) {
                                        isTextFieldFocused = false
                                    }
                                }
                            }
                        
                        Text("\(memoText.count)/100")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 4)
                    }
                    .padding(.vertical)
                    
                    // Add some spacing before buttons
                    Spacer()
                        .frame(minHeight: 20)
                    
                    // Action buttons
                    VStack(spacing: 15) {
                        Button(action: save) {
                            Text("memo.save".localized)
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.accentColor)
                                .cornerRadius(12)
                        }
                        .disabled(memoText.isEmpty || memoText.count > 100)
                        
                        if !initialContent.isEmpty {
                            Button(action: delete) {
                                Text("memo.delete".localized)
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            memoText = initialContent
            // Auto-focus the text field when view appears
            if initialContent.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    isTextFieldFocused = true
                }
            }
        }
    }
    
    private func save() {
        let trimmedText = memoText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedText.isEmpty {
            onSave(trimmedText)
        }
        dismiss()
    }
    
    private func delete() {
        onDelete()
        dismiss()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    MemoEditorView(
        date: Date(),
        initialContent: "",
        onSave: { _ in },
        onDelete: { }
    )
}