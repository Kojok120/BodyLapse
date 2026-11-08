import Foundation
import Testing
@testable import BodyLapse

struct PINAttemptPolicyTests {

    @Test
    func testNoLockoutWithinFreeAttempts() {
        for count in 0..<PINAttemptPolicy.freeAttempts {
            #expect(PINAttemptPolicy.lockoutDuration(afterFailures: count) == 0)
        }
    }

    @Test
    func testLockoutGrowsAndCaps() {
        #expect(PINAttemptPolicy.lockoutDuration(afterFailures: 5) == 30)
        #expect(PINAttemptPolicy.lockoutDuration(afterFailures: 6) == 60)
        #expect(PINAttemptPolicy.lockoutDuration(afterFailures: 7) == 300)
        #expect(PINAttemptPolicy.lockoutDuration(afterFailures: 8) == 900)
        #expect(PINAttemptPolicy.lockoutDuration(afterFailures: 9) == 3600)
        #expect(PINAttemptPolicy.lockoutDuration(afterFailures: 50) == 3600)
    }

    @Test
    func testRemainingLockout() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(PINAttemptPolicy.remainingLockout(until: nil, now: now) == 0)
        #expect(PINAttemptPolicy.remainingLockout(until: now.addingTimeInterval(-1), now: now) == 0)
        #expect(PINAttemptPolicy.remainingLockout(until: now.addingTimeInterval(42), now: now) == 42)
        // 時計を戻されても最長の待ち時間で頭打ち
        #expect(PINAttemptPolicy.remainingLockout(until: now.addingTimeInterval(999_999), now: now) == 3600)
    }

    @Test
    func testAttemptsBeforeLockout() {
        #expect(PINAttemptPolicy.attemptsBeforeLockout(failureCount: 0) == 5)
        #expect(PINAttemptPolicy.attemptsBeforeLockout(failureCount: 4) == 1)
        #expect(PINAttemptPolicy.attemptsBeforeLockout(failureCount: 7) == 0)
    }
}
