import Foundation
import Testing
@testable import BodyLapse

struct AchievementCelebrationTests {

    @Test
    func testOnlyTheBiggestMilestoneIsCelebrated() {
        let unlocked = Achievement.all.filter { ["streak_3", "streak_7", "total_30", "streak_14"].contains($0.id) }
        let shown = AchievementService.celebrations(for: unlocked)
        #expect(shown.map(\.id) == ["total_30"])
        #expect(AchievementService.celebrations(for: []).isEmpty)
    }
}
