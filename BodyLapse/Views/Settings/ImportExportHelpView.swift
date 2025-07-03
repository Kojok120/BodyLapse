import SwiftUI

struct ImportExportHelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var expandedSection: String? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Overview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("import_export.help_overview_title".localized)
                            .font(.headline)
                        
                        Text("import_export.help_overview_description".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Export Section
                    VStack(alignment: .leading, spacing: 0) {
                        Button(action: {
                            withAnimation {
                                expandedSection = expandedSection == "export" ? nil : "export"
                            }
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.bodyLapseTurquoise)
                                    .frame(width: 30)
                                
                                Text("import_export.help_export_title".localized)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: expandedSection == "export" ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        
                        if expandedSection == "export" {
                            VStack(alignment: .leading, spacing: 16) {
                                // What gets exported
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("import_export.help_export_what".localized)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    ForEach(exportItems, id: \.self) { item in
                                        Label(item, systemImage: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                // Export options
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("import_export.help_export_options".localized)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    Text("import_export.help_export_options_description".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                // File format
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("import_export.help_export_format".localized)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    Text("import_export.help_export_format_description".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .transition(.opacity)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Import Section
                    VStack(alignment: .leading, spacing: 0) {
                        Button(action: {
                            withAnimation {
                                expandedSection = expandedSection == "import" ? nil : "import"
                            }
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                    .foregroundColor(.bodyLapseTurquoise)
                                    .frame(width: 30)
                                
                                Text("import_export.help_import_title".localized)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: expandedSection == "import" ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        
                        if expandedSection == "import" {
                            VStack(alignment: .leading, spacing: 16) {
                                // Import types
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("import_export.help_import_types".localized)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    // Full backup import
                                    VStack(alignment: .leading, spacing: 4) {
                                        Label("import_export.help_import_backup".localized, systemImage: "doc.zipper")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Text("import_export.help_import_backup_description".localized)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 28)
                                    }
                                    
                                    // Single photo import
                                    VStack(alignment: .leading, spacing: 4) {
                                        Label("import_export.help_import_photo".localized, systemImage: "photo")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Text("import_export.help_import_photo_description".localized)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 28)
                                    }
                                }
                                
                                // Merge strategies
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("import_export.help_merge_strategies".localized)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    ForEach(mergeStrategies, id: \.title) { strategy in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Label(strategy.title, systemImage: strategy.icon)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                            Text(strategy.description)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .padding(.leading, 28)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .transition(.opacity)
                        }
                    }
                    .padding(.horizontal)
                    
                    // FAQ Section
                    VStack(alignment: .leading, spacing: 0) {
                        Button(action: {
                            withAnimation {
                                expandedSection = expandedSection == "faq" ? nil : "faq"
                            }
                        }) {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                    .foregroundColor(.bodyLapseTurquoise)
                                    .frame(width: 30)
                                
                                Text("import_export.help_faq_title".localized)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: expandedSection == "faq" ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        
                        if expandedSection == "faq" {
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(faqItems, id: \.question) { item in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.question)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Text(item.answer)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .transition(.opacity)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Tips
                    VStack(alignment: .leading, spacing: 12) {
                        Text("import_export.help_tips_title".localized)
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(tips, id: \.self) { tip in
                                Label(tip, systemImage: "lightbulb.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("import_export.help_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var exportItems: [String] {
        [
            "import_export.help_export_item_photos".localized,
            "import_export.help_export_item_videos".localized,
            "import_export.help_export_item_weight".localized,
            "import_export.help_export_item_notes".localized,
            "import_export.help_export_item_categories".localized,
            "import_export.help_export_item_settings".localized
        ]
    }
    
    private var mergeStrategies: [(title: String, icon: String, description: String)] {
        [
            (
                title: "import_export.help_merge_skip".localized,
                icon: "arrow.right.circle",
                description: "import_export.help_merge_skip_description".localized
            ),
            (
                title: "import_export.help_merge_replace".localized,
                icon: "arrow.triangle.2.circlepath",
                description: "import_export.help_merge_replace_description".localized
            )
        ]
    }
    
    private var faqItems: [(question: String, answer: String)] {
        [
            (
                question: "import_export.help_faq_q1".localized,
                answer: "import_export.help_faq_a1".localized
            ),
            (
                question: "import_export.help_faq_q2".localized,
                answer: "import_export.help_faq_a2".localized
            ),
            (
                question: "import_export.help_faq_q3".localized,
                answer: "import_export.help_faq_a3".localized
            ),
            (
                question: "import_export.help_faq_q4".localized,
                answer: "import_export.help_faq_a4".localized
            ),
            (
                question: "import_export.help_faq_q5".localized,
                answer: "import_export.help_faq_a5".localized
            )
        ]
    }
    
    private var tips: [String] {
        [
            "import_export.help_tip1".localized,
            "import_export.help_tip2".localized,
            "import_export.help_tip3".localized,
            "import_export.help_tip4".localized
        ]
    }
}