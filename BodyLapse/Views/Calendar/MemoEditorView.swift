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
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "note.text")
                        .font(.system(size: 50))
                        .foregroundColor(.accentColor)
                    
                    Text("メモを追加")
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
                    Text("メモ内容")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                    
                    TextEditor(text: $memoText)
                        .font(.body)
                        .padding(8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .focused($isTextFieldFocused)
                        .onChange(of: memoText) { _, newValue in
                            if newValue.count > 100 {
                                memoText = String(newValue.prefix(100))
                            }
                        }
                    
                    Text("\(memoText.count)/100")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }
                .padding(.vertical)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 15) {
                    Button(action: save) {
                        Text("保存")
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
                            Text("メモを削除")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            memoText = initialContent
            // Auto-focus the text field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
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
        formatter.dateFormat = "yyyy年MM月dd日"
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