import SwiftUI
import UIKit

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
                        
                        ZStack(alignment: .bottomTrailing) {
                            TextEditor(text: $memoText)
                                .font(.body)
                                .padding(8)
                                .frame(height: 150)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                                .focused($isTextFieldFocused)
                                .scrollContentBackground(.hidden)
                                .onChange(of: memoText) { _, newValue in
                                    if newValue.count > 500 {
                                        memoText = String(newValue.prefix(500))
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
                            
                            Button {
                                copyMemo()
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(copyButtonBackground)
                                    .clipShape(Circle())
                            }
                            .disabled(!canCopyMemo)
                            .opacity(canCopyMemo ? 1 : 0.4)
                            .padding(12)
                            .accessibilityLabel(Text("common.copy".localized))
                        }
                        .padding(.horizontal)
                        
                        Text("\(memoText.count)/500")
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
                        .disabled(memoText.isEmpty || memoText.count > 500)
                        
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
    
    private func copyMemo() {
        let trimmed = memoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UIPasteboard.general.string = trimmed
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private var canCopyMemo: Bool {
        !memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var copyButtonBackground: Color {
        canCopyMemo ? .bodyLapseTurquoise : Color(UIColor.systemGray4)
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
