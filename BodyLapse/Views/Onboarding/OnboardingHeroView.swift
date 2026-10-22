import SwiftUI

/// オンボーディング初回画面の上半分。毎日撮った写真がフィルムに溜まり、パラパラ動画になる流れを見せる
struct OnboardingHeroView: View {
    /// 表示中のページのときだけ動かす
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date()

    var body: some View {
        Group {
            if reduceMotion {
                OnboardingHeroContent(frame: OnboardingHeroTimeline.staticFrame)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isActive)) { context in
                    OnboardingHeroContent(
                        frame: OnboardingHeroTimeline.frame(at: context.date.timeIntervalSince(startDate))
                    )
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("onboarding.hero.accessibility".localized)
        .onChange(of: isActive) { _, active in
            // ページに戻ってきたら撮影から見せ直す
            if active {
                startDate = Date()
            }
        }
    }
}

private struct OnboardingHeroContent: View {
    let frame: OnboardingHeroFrame

    private var isReplaying: Bool {
        frame.phase != .capturing
    }

    var body: some View {
        VStack(spacing: 12) {
            viewfinder
            shutter
            filmstrip
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }

    // MARK: - ファインダー

    private var viewfinder: some View {
        ZStack {
            OnboardingFigureImage(keyframe: frame.baseKeyframe)
            OnboardingFigureImage(keyframe: frame.overlayKeyframe)
                .opacity(frame.overlayOpacity)

            // 撮影画面と同じ見た目の 1 日目の輪郭ガイド
            ZStack {
                OnboardingDayOneOutline()
                    .fill(Color.white.opacity(0.1))
                OnboardingDayOneOutline()
                    .stroke(Color.green.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            }
            .opacity(frame.showsGuide ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: frame.showsGuide)

            Color.white
                .opacity(frame.isFlashing ? 0.55 : 0)
                .animation(.easeOut(duration: 0.12), value: frame.isFlashing)
        }
        .overlay(alignment: .topLeading) {
            dayChip
                .padding(12)
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                guideNote
                progressBar
            }
            .padding(14)
        }
        .aspectRatio(OnboardingFigureImage.aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: 280, maxHeight: 420)
    }

    private var dayChip: some View {
        Text(
            frame.phase == .playing
                ? "onboarding.hero.playing".localized(with: frame.day)
                : "onboarding.hero.day".localized(with: frame.day)
        )
        .font(.footnote.weight(.bold))
        .monospacedDigit()
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.black.opacity(0.4)))
    }

    private var guideNote: some View {
        Text("onboarding.hero.guide_note".localized)
            .font(.caption.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.black.opacity(0.4)))
            .opacity(frame.showsGuideNote ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: frame.showsGuideNote)
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.35))
                Capsule()
                    .fill(Color.bodyLapseYellow)
                    .frame(width: geometry.size.width * frame.playbackProgress)
            }
        }
        .frame(height: 4)
        .opacity(frame.showsProgressBar ? 1 : 0)
    }

    // MARK: - シャッター

    private var shutter: some View {
        ZStack {
            Circle()
                .stroke(Color(UIColor.systemGray4), lineWidth: 4)
                .frame(width: 56, height: 56)

            Circle()
                .fill(isReplaying ? Color.accentColor : Color.white)
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.2), radius: 1.5, x: 0, y: 1)
                .scaleEffect(frame.isShutterPressed ? 0.82 : 1)
                .animation(.easeOut(duration: 0.09), value: frame.isShutterPressed)

            if isReplaying {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .offset(x: 1)
            }
        }
        .frame(width: 60, height: 60)
    }

    // MARK: - フィルム

    private var filmstrip: some View {
        HStack(spacing: 5) {
            ForEach(OnboardingHeroTimeline.shotDays.indices, id: \.self) { index in
                let isShown = index < frame.shotCount
                let isHighlighted = frame.highlightedShot == index
                OnboardingFigureImage(
                    keyframe: OnboardingHeroTimeline.keyframeIndex(forDay: OnboardingHeroTimeline.shotDays[index])
                )
                .scaledToFill()
                .frame(width: 30, height: 45)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.bodyLapseYellow, lineWidth: isHighlighted ? 2 : 0)
                )
                .scaleEffect(isShown ? (isHighlighted ? 1.15 : 1) : 0.3)
                .opacity(isShown ? 1 : 0)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isShown)
                .animation(.easeOut(duration: 0.15), value: isHighlighted)
            }
        }
        .frame(height: 52)
    }
}

/// 同梱の黄色い人型の画像 (OnboardingFigureDayNN)
private struct OnboardingFigureImage: View {
    /// 元画像 1696x2528 の縦横比。輪郭の座標もこの比で描く
    static let aspectRatio: CGFloat = 1696.0 / 2528.0

    let keyframe: Int

    var body: some View {
        Image(String(format: "OnboardingFigureDay%02d", OnboardingHeroTimeline.keyframeDays[keyframe]))
            .resizable()
    }
}

/// 1 日目の画像の人型の輪郭
struct OnboardingDayOneOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = Self.points.map {
            CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height)
        }
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    /// OnboardingFigureDay01 から Vision の人物切り抜き (アプリの BodyContourService と同じ
    /// VNGenerateForegroundInstanceMaskRequest) で取った輪郭。画像に対する 0〜1 の座標 (左上原点)
    static let points: [CGPoint] = [
        CGPoint(x: 0.6114, y: 0.8877), CGPoint(x: 0.6294, y: 0.8843), CGPoint(x: 0.6342, y: 0.8760), CGPoint(x: 0.6097, y: 0.8428),
        CGPoint(x: 0.6056, y: 0.8271), CGPoint(x: 0.6056, y: 0.8076), CGPoint(x: 0.6231, y: 0.7256), CGPoint(x: 0.6210, y: 0.6670),
        CGPoint(x: 0.6407, y: 0.5771), CGPoint(x: 0.6426, y: 0.5166), CGPoint(x: 0.6386, y: 0.4717), CGPoint(x: 0.6410, y: 0.4648),
        CGPoint(x: 0.6439, y: 0.4637), CGPoint(x: 0.6461, y: 0.4658), CGPoint(x: 0.6602, y: 0.5029), CGPoint(x: 0.6602, y: 0.5146),
        CGPoint(x: 0.6491, y: 0.5459), CGPoint(x: 0.6491, y: 0.5537), CGPoint(x: 0.6555, y: 0.5584), CGPoint(x: 0.6672, y: 0.5538),
        CGPoint(x: 0.6694, y: 0.5557), CGPoint(x: 0.6661, y: 0.5635), CGPoint(x: 0.6566, y: 0.5732), CGPoint(x: 0.6550, y: 0.5850),
        CGPoint(x: 0.6613, y: 0.5893), CGPoint(x: 0.6672, y: 0.5897), CGPoint(x: 0.6872, y: 0.5791), CGPoint(x: 0.7008, y: 0.5615),
        CGPoint(x: 0.7088, y: 0.5381), CGPoint(x: 0.7148, y: 0.4834), CGPoint(x: 0.7130, y: 0.4209), CGPoint(x: 0.7047, y: 0.3877),
        CGPoint(x: 0.6842, y: 0.3369), CGPoint(x: 0.6725, y: 0.3115), CGPoint(x: 0.6602, y: 0.2939), CGPoint(x: 0.6410, y: 0.2804),
        CGPoint(x: 0.6052, y: 0.2646), CGPoint(x: 0.5464, y: 0.2412), CGPoint(x: 0.5453, y: 0.2275), CGPoint(x: 0.5552, y: 0.2080),
        CGPoint(x: 0.5683, y: 0.1944), CGPoint(x: 0.5721, y: 0.1865), CGPoint(x: 0.5698, y: 0.1787), CGPoint(x: 0.5629, y: 0.1709),
        CGPoint(x: 0.5581, y: 0.1475), CGPoint(x: 0.5509, y: 0.1358), CGPoint(x: 0.5392, y: 0.1280), CGPoint(x: 0.5189, y: 0.1212),
        CGPoint(x: 0.5018, y: 0.1201), CGPoint(x: 0.4726, y: 0.1240), CGPoint(x: 0.4552, y: 0.1318), CGPoint(x: 0.4437, y: 0.1436),
        CGPoint(x: 0.4371, y: 0.1689), CGPoint(x: 0.4280, y: 0.1846), CGPoint(x: 0.4302, y: 0.1924), CGPoint(x: 0.4449, y: 0.2080),
        CGPoint(x: 0.4525, y: 0.2217), CGPoint(x: 0.4571, y: 0.2354), CGPoint(x: 0.4520, y: 0.2459), CGPoint(x: 0.4317, y: 0.2568),
        CGPoint(x: 0.3968, y: 0.2646), CGPoint(x: 0.3478, y: 0.2881), CGPoint(x: 0.3276, y: 0.3135), CGPoint(x: 0.3111, y: 0.3506),
        CGPoint(x: 0.2917, y: 0.4033), CGPoint(x: 0.2853, y: 0.4385), CGPoint(x: 0.2853, y: 0.4834), CGPoint(x: 0.2929, y: 0.5459),
        CGPoint(x: 0.3045, y: 0.5693), CGPoint(x: 0.3167, y: 0.5811), CGPoint(x: 0.3358, y: 0.5899), CGPoint(x: 0.3445, y: 0.5859),
        CGPoint(x: 0.3434, y: 0.5713), CGPoint(x: 0.3301, y: 0.5557), CGPoint(x: 0.3474, y: 0.5577), CGPoint(x: 0.3531, y: 0.5518),
        CGPoint(x: 0.3398, y: 0.5146), CGPoint(x: 0.3398, y: 0.5049), CGPoint(x: 0.3561, y: 0.4620), CGPoint(x: 0.3590, y: 0.4628),
        CGPoint(x: 0.3614, y: 0.4697), CGPoint(x: 0.3593, y: 0.5752), CGPoint(x: 0.3633, y: 0.6045), CGPoint(x: 0.3790, y: 0.6631),
        CGPoint(x: 0.3791, y: 0.7373), CGPoint(x: 0.3965, y: 0.8174), CGPoint(x: 0.3904, y: 0.8447), CGPoint(x: 0.3677, y: 0.8720),
        CGPoint(x: 0.3656, y: 0.8818), CGPoint(x: 0.3706, y: 0.8856), CGPoint(x: 0.3852, y: 0.8885), CGPoint(x: 0.4288, y: 0.8886),
        CGPoint(x: 0.4396, y: 0.8838), CGPoint(x: 0.4625, y: 0.8584), CGPoint(x: 0.4589, y: 0.8174), CGPoint(x: 0.4746, y: 0.7275),
        CGPoint(x: 0.4726, y: 0.6768), CGPoint(x: 0.4824, y: 0.6162), CGPoint(x: 0.4882, y: 0.5986), CGPoint(x: 0.4926, y: 0.5479),
        CGPoint(x: 0.4956, y: 0.5362), CGPoint(x: 0.5015, y: 0.5334), CGPoint(x: 0.5077, y: 0.5459), CGPoint(x: 0.5136, y: 0.6064),
        CGPoint(x: 0.5274, y: 0.6748), CGPoint(x: 0.5253, y: 0.7334), CGPoint(x: 0.5411, y: 0.8096), CGPoint(x: 0.5376, y: 0.8584),
        CGPoint(x: 0.5545, y: 0.8799), CGPoint(x: 0.5654, y: 0.8873)
    ]
}
