import UIKit

/// SNS共有用のビフォーアフター合成画像を生成するサービス。
/// 既存の動画生成パイプラインには触れず、独立した画像合成として提供する。
/// 全ユーザーが利用でき、Pro以外はウォーターマークを付与する（共有経由の宣伝にもなる）。
enum ShareComposerService {

    /// ビフォーアフターを横並びに合成した共有用画像を返す。
    static func beforeAfterImage(
        before: UIImage,
        after: UIImage,
        beforeLabel: String,
        afterLabel: String,
        beforeDateText: String?,
        afterDateText: String?,
        addWatermark: Bool,
        canvasSize: CGSize = CGSize(width: 1080, height: 1350)
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvasSize))

            let halfWidth = canvasSize.width / 2
            let leftRect = CGRect(x: 0, y: 0, width: halfWidth, height: canvasSize.height)
            let rightRect = CGRect(x: halfWidth, y: 0, width: halfWidth, height: canvasSize.height)

            drawAspectFit(before, in: leftRect)
            drawAspectFit(after, in: rightRect)

            // 中央の仕切り線
            UIColor.white.withAlphaComponent(0.7).setFill()
            ctx.fill(CGRect(x: halfWidth - 1, y: 0, width: 2, height: canvasSize.height))

            drawBadge(title: beforeLabel, subtitle: beforeDateText, at: CGPoint(x: 20, y: 20))
            drawBadge(title: afterLabel, subtitle: afterDateText, at: CGPoint(x: halfWidth + 20, y: 20))

            if addWatermark {
                drawWatermark(in: CGRect(origin: .zero, size: canvasSize))
            }
        }
    }

    // MARK: - 描画ヘルパー

    private static func drawAspectFit(_ image: UIImage, in rect: CGRect) {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }
        let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(x: rect.midX - drawSize.width / 2, y: rect.midY - drawSize.height / 2)
        image.draw(in: CGRect(origin: origin, size: drawSize))
    }

    private static func drawBadge(title: String, subtitle: String?, at point: CGPoint) {
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 36, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]

        let titleSize = (title as NSString).size(withAttributes: titleAttrs)
        let subtitleSize = subtitle.map { ($0 as NSString).size(withAttributes: subtitleAttrs) } ?? .zero

        let padding: CGFloat = 12
        let contentWidth = max(titleSize.width, subtitleSize.width)
        let contentHeight = titleSize.height + (subtitle != nil ? subtitleSize.height + 4 : 0)
        let bgRect = CGRect(x: point.x, y: point.y, width: contentWidth + padding * 2, height: contentHeight + padding * 2)

        let path = UIBezierPath(roundedRect: bgRect, cornerRadius: 10)
        UIColor.black.withAlphaComponent(0.45).setFill()
        path.fill()

        (title as NSString).draw(at: CGPoint(x: bgRect.minX + padding, y: bgRect.minY + padding), withAttributes: titleAttrs)
        if let subtitle {
            (subtitle as NSString).draw(
                at: CGPoint(x: bgRect.minX + padding, y: bgRect.minY + padding + titleSize.height + 4),
                withAttributes: subtitleAttrs
            )
        }
    }

    private static func drawWatermark(in rect: CGRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 30, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.85)
        ]
        let text = "BodyLapse" as NSString
        let size = text.size(withAttributes: attrs)
        text.draw(at: CGPoint(x: rect.maxX - size.width - 24, y: rect.maxY - size.height - 20), withAttributes: attrs)
    }
}
