import SwiftUI

/// 実績解除時に表示する祝福カード。
struct AchievementCelebrationCard: View {
    let achievement: Achievement
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange, Color.bodyLapseTurquoise],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                Image(systemName: achievement.iconName)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.white)
            }
            .scaleEffect(appeared ? 1 : 0.4)
            .opacity(appeared ? 1 : 0)

            Text("achievement.unlocked".localized)
                .font(.headline)
                .foregroundColor(.secondary)

            Text(achievement.displayName)
                .font(.title2.bold())
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            Text(achievement.praiseMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onDismiss) {
                Text("common.done".localized)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.bodyLapseTurquoise)
                    .cornerRadius(12)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 20)
        .padding(.horizontal, 40)
        .scaleEffect(appeared ? 1 : 0.85)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.displayName). \(achievement.praiseMessage)")
    }
}

/// 祝福キューを監視し、未表示の実績があればカードを重ねて表示するオーバーレイ。
/// アプリのルート（MainTabView）に被せて使う。
struct AchievementCelebrationOverlay: View {
    @StateObject private var achievementService = AchievementService.shared

    var body: some View {
        ZStack {
            if let achievement = achievementService.pendingCelebrations.first {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .transition(.opacity)

                AchievementCelebrationCard(achievement: achievement) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        achievementService.dismissCurrentCelebration()
                    }
                }
                .id(achievement.id)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: achievementService.pendingCelebrations.first?.id)
    }
}
