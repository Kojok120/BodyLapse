import Foundation

/// オンボーディング初回画面のアニメーション (撮影 → フィルムに溜まる → パラパラ再生) のある時点の表示内容
struct OnboardingHeroFrame: Equatable {
    enum Phase: Equatable {
        /// シャッターを切ってフィルムに溜めている
        case capturing
        /// フィルムを再生している
        case playing
        /// 再生し終えて 90 日目で止まっている
        case finished
    }

    let phase: Phase
    /// フィルムに溜まったコマ数 (0...shotDays.count)
    let shotCount: Int
    let isShutterPressed: Bool
    let isFlashing: Bool
    /// ファインダーに出す日数
    let day: Int
    /// 下に敷くキーフレームと、上に重ねるキーフレーム (keyframeDays の index)
    let baseKeyframe: Int
    let overlayKeyframe: Int
    /// 上に重ねるキーフレームの不透明度 (0...1)。キーフレームの間をクロスフェードでつなぐ
    let overlayOpacity: Double
    /// 再生の進み具合 (0...1)
    let playbackProgress: Double
    /// 再生中に強調するフィルムのコマ
    let highlightedShot: Int?
    /// 1 日目の輪郭ガイドを出すか
    let showsGuide: Bool
    /// 「緑の線は 1 日目の輪郭」の注記を出すか
    let showsGuideNote: Bool
    let showsProgressBar: Bool
}

enum OnboardingHeroTimeline {
    /// フィルムに溜まる 8 コマの日数
    static let shotDays = [1, 13, 26, 39, 52, 65, 78, 90]
    /// 同梱している画像の日数 (OnboardingFigureDayNN)
    static let keyframeDays = [1, 30, 60, 90]

    static let cycleDuration: TimeInterval = 10.2

    private static let firstShotTime: TimeInterval = 0.48
    private static let shootingSpan: TimeInterval = 3.72
    private static let shutterPressDuration: TimeInterval = 0.12
    private static let flashDuration: TimeInterval = 0.18
    private static let replayStart: TimeInterval = 4.8
    private static let playbackStart: TimeInterval = 5.04
    private static let playbackDuration: TimeInterval = 2.04
    private static let playbackEnd: TimeInterval = 7.32
    private static let compareStart: TimeInterval = 7.68
    private static let compareEnd: TimeInterval = 9.96

    /// k 枚目 (0 始まり) のシャッターを切る時刻。後半ほど間隔を詰めて「毎日溜まっていく」速さを出す
    static func shotTime(index: Int) -> TimeInterval {
        let ratio = Double(index) / Double(shotDays.count - 1)
        return firstShotTime + shootingSpan * pow(ratio, 0.7)
    }

    /// その日に最も近いキーフレームの index
    static func keyframeIndex(forDay day: Int) -> Int {
        let firstDay = Double(keyframeDays[0])
        let lastDay = Double(keyframeDays[keyframeDays.count - 1])
        let ratio = (Double(day) - firstDay) / (lastDay - firstDay)
        let index = Int((ratio * Double(keyframeDays.count - 1)).rounded())
        return min(max(index, 0), keyframeDays.count - 1)
    }

    /// 経過時間 (秒) の時点の表示内容。cycleDuration で繰り返す
    static func frame(at time: TimeInterval) -> OnboardingHeroFrame {
        let t = max(0, time).truncatingRemainder(dividingBy: cycleDuration)
        let shotTimes = shotDays.indices.map { shotTime(index: $0) }
        let shotCount = shotTimes.filter { t >= $0 }.count

        if t < replayStart {
            let day = shotCount > 0 ? shotDays[shotCount - 1] : shotDays[0]
            let keyframe = keyframeIndex(forDay: day)
            return OnboardingHeroFrame(
                phase: .capturing,
                shotCount: shotCount,
                isShutterPressed: shotTimes.contains { t >= $0 && t < $0 + shutterPressDuration },
                isFlashing: shotTimes.contains { t >= $0 && t < $0 + flashDuration },
                day: day,
                baseKeyframe: keyframe,
                overlayKeyframe: keyframe,
                overlayOpacity: 0,
                playbackProgress: 0,
                highlightedShot: nil,
                showsGuide: shotCount > 0,
                showsGuideNote: false,
                showsProgressBar: false
            )
        }

        let progress = min(max((t - playbackStart) / playbackDuration, 0), 1)
        let position = progress * Double(keyframeDays.count - 1)
        let base = min(Int(position), keyframeDays.count - 2)
        let firstDay = Double(shotDays[0])
        let lastDay = Double(shotDays[shotDays.count - 1])
        let isComparing = t >= compareStart && t < compareEnd
        return OnboardingHeroFrame(
            phase: t < playbackEnd ? .playing : .finished,
            shotCount: shotDays.count,
            isShutterPressed: false,
            isFlashing: false,
            day: Int((firstDay + progress * (lastDay - firstDay)).rounded()),
            baseKeyframe: base,
            overlayKeyframe: base + 1,
            overlayOpacity: min(position - Double(base), 1),
            playbackProgress: progress,
            highlightedShot: min(Int(progress * Double(shotDays.count)), shotDays.count - 1),
            showsGuide: isComparing,
            showsGuideNote: isComparing,
            showsProgressBar: t < compareEnd
        )
    }

    /// 視差効果を減らす設定のときに出す静止状態 (90 日目に 1 日目の輪郭を重ねる)
    static let staticFrame = OnboardingHeroFrame(
        phase: .finished,
        shotCount: shotDays.count,
        isShutterPressed: false,
        isFlashing: false,
        day: shotDays[shotDays.count - 1],
        baseKeyframe: keyframeDays.count - 1,
        overlayKeyframe: keyframeDays.count - 1,
        overlayOpacity: 0,
        playbackProgress: 1,
        highlightedShot: nil,
        showsGuide: true,
        showsGuideNote: true,
        showsProgressBar: false
    )
}
