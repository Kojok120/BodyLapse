import Foundation
import Testing
@testable import BodyLapse

struct OnboardingHeroTimelineTests {

    private let shotDays = OnboardingHeroTimeline.shotDays
    private let lastShotTime = OnboardingHeroTimeline.shotTime(index: OnboardingHeroTimeline.shotDays.count - 1)

    @Test
    func 始まりはフィルムが空で輪郭も出ない() {
        let frame = OnboardingHeroTimeline.frame(at: 0)
        #expect(frame.phase == .capturing)
        #expect(frame.shotCount == 0)
        #expect(frame.day == 1)
        #expect(frame.showsGuide == false)
        #expect(frame.showsProgressBar == false)
    }

    @Test
    func 撮影中はコマが減らずに増えて最後に全部溜まる() {
        var previous = 0
        var time = 0.0
        while time < lastShotTime + 0.3 {
            let frame = OnboardingHeroTimeline.frame(at: time)
            #expect(frame.phase == .capturing)
            #expect(frame.shotCount >= previous)
            previous = frame.shotCount
            time += 0.01
        }
        #expect(previous == shotDays.count)
    }

    @Test
    func シャッターを切った直後は押下とフラッシュが出て日数がそのコマになる() {
        let index = 3
        let frame = OnboardingHeroTimeline.frame(at: OnboardingHeroTimeline.shotTime(index: index) + 0.05)
        #expect(frame.isShutterPressed)
        #expect(frame.isFlashing)
        #expect(frame.shotCount == index + 1)
        #expect(frame.day == shotDays[index])
        #expect(frame.showsGuide)
    }

    @Test
    func 再生中は日数が戻らず最後は90日目のキーフレームになる() {
        var previousDay = 0
        var time = 4.8
        while time < 7.3 {
            let frame = OnboardingHeroTimeline.frame(at: time)
            #expect(frame.phase == .playing)
            #expect(frame.shotCount == shotDays.count)
            #expect(frame.day >= previousDay)
            #expect(frame.overlayKeyframe == frame.baseKeyframe + 1)
            #expect((0...1).contains(frame.overlayOpacity))
            previousDay = frame.day
            time += 0.01
        }
        #expect(previousDay == 90)

        let end = OnboardingHeroTimeline.frame(at: 7.2)
        #expect(end.overlayKeyframe == OnboardingHeroTimeline.keyframeDays.count - 1)
        #expect(end.overlayOpacity == 1)
        #expect(end.playbackProgress == 1)
        #expect(end.highlightedShot == shotDays.count - 1)
    }

    @Test
    func 再生後は90日目に1日目の輪郭と注記を重ねる() {
        let frame = OnboardingHeroTimeline.frame(at: 8.5)
        #expect(frame.phase == .finished)
        #expect(frame.day == 90)
        #expect(frame.showsGuide)
        #expect(frame.showsGuideNote)
    }

    @Test
    func 一周すると最初に戻る() {
        let cycle = OnboardingHeroTimeline.cycleDuration
        #expect(OnboardingHeroTimeline.frame(at: cycle + 1.234) == OnboardingHeroTimeline.frame(at: 1.234))
        #expect(OnboardingHeroTimeline.frame(at: cycle * 2 + 6.0) == OnboardingHeroTimeline.frame(at: 6.0))
    }

    @Test
    func 撮影日は最も近いキーフレームに割り当てる() {
        let indices = shotDays.map { OnboardingHeroTimeline.keyframeIndex(forDay: $0) }
        #expect(indices == [0, 0, 1, 1, 2, 2, 3, 3])
        #expect(OnboardingHeroTimeline.keyframeIndex(forDay: 0) == 0)
        #expect(OnboardingHeroTimeline.keyframeIndex(forDay: 120) == 3)
    }

    @Test
    func 視差効果を減らす設定では90日目に輪郭を重ねた静止状態() {
        let frame = OnboardingHeroTimeline.staticFrame
        #expect(frame.day == 90)
        #expect(frame.baseKeyframe == OnboardingHeroTimeline.keyframeDays.count - 1)
        #expect(frame.shotCount == shotDays.count)
        #expect(frame.showsGuide)
        #expect(frame.showsGuideNote)
        #expect(frame.showsProgressBar == false)
    }

    @Test
    func 輪郭の座標は画像の内側に収まる() {
        let points = OnboardingDayOneOutline.points
        #expect(points.count > 50)
        #expect(points.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
    }
}
