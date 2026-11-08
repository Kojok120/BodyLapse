import Foundation

/// PIN の連続失敗に対する待ち時間の決まり (純関数)
enum PINAttemptPolicy {
    /// 待ち時間なしで試せる回数
    static let freeAttempts = 5
    /// 失敗を重ねるごとの待ち時間。最後の値で頭打ち
    static let lockoutSteps: [TimeInterval] = [30, 60, 300, 900, 3600]

    /// failureCount 回失敗した直後に課す待ち時間 (秒)。0 なら待たずに次を試せる
    static func lockoutDuration(afterFailures failureCount: Int) -> TimeInterval {
        guard failureCount >= freeAttempts else { return 0 }
        let index = min(failureCount - freeAttempts, lockoutSteps.count - 1)
        return lockoutSteps[index]
    }

    /// 待ちが終わるまでの残り秒数。端末の時計を戻しても最長の待ち時間を超えない
    static func remainingLockout(until lockoutUntil: Date?, now: Date) -> TimeInterval {
        guard let lockoutUntil else { return 0 }
        let remaining = lockoutUntil.timeIntervalSince(now)
        guard remaining > 0 else { return 0 }
        return min(remaining, lockoutSteps.last ?? remaining)
    }

    /// 待ち時間に入るまでに残っている試行回数
    static func attemptsBeforeLockout(failureCount: Int) -> Int {
        max(0, freeAttempts - failureCount)
    }
}
