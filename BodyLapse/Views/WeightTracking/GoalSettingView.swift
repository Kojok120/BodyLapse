import SwiftUI

/// 体重目標（ゴール）の設定シート。全ユーザー無料。
/// 入力はユーザーの単位（kg/lbs）で受け取り、保存時にkgへ変換する。
struct GoalSettingView: View {
    @ObservedObject private var userSettings = UserSettingsManager.shared
    @Environment(\.dismiss) private var dismiss

    /// 参考表示用の現在体重（kg）。
    let currentWeightKg: Double?

    @State private var goalText: String = ""
    @State private var hasTargetDate: Bool = false
    @State private var targetDate: Date = Date()

    private var unit: UserSettings.WeightUnit { userSettings.settings.weightUnit }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        TextField("goal.weight_placeholder".localized, text: $goalText)
                            .keyboardType(.decimalPad)
                        Text(unit.symbol)
                            .foregroundColor(.secondary)
                    }
                    if let currentKg = currentWeightKg {
                        Text("goal.current_hint".localized(with: formatWeight(currentKg)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("goal.weight_section".localized)
                }

                Section {
                    Toggle("goal.set_target_date".localized, isOn: $hasTargetDate.animation())
                    if hasTargetDate {
                        DatePicker(
                            "goal.target_date".localized,
                            selection: $targetDate,
                            in: Date()...,
                            displayedComponents: .date
                        )
                    }
                }

                if userSettings.settings.goalWeight != nil {
                    Section {
                        Button(role: .destructive, action: clearGoal) {
                            Text("goal.clear".localized)
                        }
                    }
                }
            }
            .navigationTitle("goal.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.save".localized) { saveGoal() }
                        .disabled(parsedGoalKg == nil)
                }
            }
            .onAppear(perform: prefill)
        }
    }

    // MARK: - ロジック

    private var parsedGoalKg: Double? {
        guard let value = Double(goalText.replacingOccurrences(of: ",", with: ".")), value > 0 else { return nil }
        return unit == .kg ? value : value / 2.20462
    }

    private func prefill() {
        if let goalKg = userSettings.settings.goalWeight {
            let display = unit == .kg ? goalKg : goalKg * 2.20462
            goalText = String(format: "%.1f", display)
        }
        if let date = userSettings.settings.goalDate {
            hasTargetDate = true
            // DatePickerの範囲(Date()...)に合わせ、過去日が保存されていても未来側にクランプする
            targetDate = max(date, Date())
        }
    }

    private func saveGoal() {
        guard let goalKg = parsedGoalKg else { return }
        userSettings.settings.goalWeight = goalKg
        userSettings.settings.goalDate = hasTargetDate ? targetDate : nil
        Haptics.success()
        dismiss()
    }

    private func clearGoal() {
        userSettings.settings.goalWeight = nil
        userSettings.settings.goalDate = nil
        dismiss()
    }

    private func formatWeight(_ kg: Double) -> String {
        let value = unit == .kg ? kg : kg * 2.20462
        return String(format: "%.1f %@", value, unit.symbol)
    }
}
