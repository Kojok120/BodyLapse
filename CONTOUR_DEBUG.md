# BodyLapse 輪郭検出問題 - デバッグドキュメント

## 問題の概要
BodyLapse アプリのオンボーディングフローで、VNGenerateForegroundInstanceMaskRequest を使用した体の輪郭検出が正しく機能していない。緑色の輪郭線が体の外形を適切にトレースできず、画面の右側に偏って表示される。

## 環境情報
- iOS: 17.0以上
- Vision Framework: VNGenerateForegroundInstanceMaskRequest (iOS 17.0+)
- マスクフォーマット: 1278226534 (UInt8形式、0-255の値範囲)
- マスクサイズ: 4032x3024

## デバッグログから判明した情報
```
Detected 1 instances, using instance: 1
Mask size: 4032x3024
Pixel format: 1278226534
Pixel value range: 0 - 255
Foreground pixels: 1824549 out of 12192768
Using threshold: 127
Found 973857 edge pixels
Traced contour with X points
```

## 試行した解決方法

### 1. 放射状スキャンアルゴリズム (初回実装)
```swift
// 中心から360方向にスキャンして輪郭を検出
let numAngles = 360
for angle in 0..<numAngles {
    // 各角度で最も遠い前景ピクセルを検出
}
```
**結果**: 輪郭点は検出されたが、画面右側に偏って表示された

### 2. エッジ検出 + Moore近傍追跡
```swift
// 全エッジピクセルを検出
for y in 1..<height-1 {
    for x in 1..<width-1 {
        if currentPixel > threshold && hasBackgroundNeighbor {
            edgePixels.append((x: x, y: y))
        }
    }
}
// Moore近傍追跡でエッジを追跡
```
**結果**: 大量のエッジピクセルは検出できたが、連続した輪郭の生成に失敗

### 3. 重心ベースの改善
```swift
// マスクの重心を計算して中心点として使用
var centerX = sumX / pixelCount
var centerY = sumY / pixelCount
```
**結果**: 中心点の精度は向上したが、輪郭検出の問題は解決せず

### 4. しきい値の動的調整
```swift
let threshold: UInt8 = maxPixelValue > 1 ? maxPixelValue / 2 : 0
```
**結果**: しきい値127で適切に設定されているが、輪郭検出の改善には至らず

### 5. Float32形式への対応
```swift
if pixelFormat == kCVPixelFormatType_DepthFloat32 {
    extractContourFromFloatMask(...)
}
```
**結果**: 現在のマスクはUInt8形式のため、この対応は不要だった

### 6. 凸包アルゴリズム (Graham scan)
```swift
private func convexHull(points: [CGPoint]) -> [CGPoint]
```
**結果**: 実装したが、人体の凹部分が表現できないため不適切

### 7. 角度ベースのソート
```swift
let sortedContour = contourPoints.sorted { point1, point2 in
    let angle1 = atan2(point1.y - centerY, point1.x - centerX)
    let angle2 = atan2(point2.y - centerY, point2.x - centerX)
    return angle1 < angle2
}
```
**結果**: エッジピクセルの順序は改善したが、表示問題は解決せず

## 根本的な問題の可能性

### 1. マスクの品質
- VNGenerateForegroundInstanceMaskRequest が生成するマスクが部分的である可能性
- デバッグ用に保存されたマスク画像の確認が必要

### 2. 座標変換の問題
- マスク座標から画像座標への変換で誤差が生じている可能性
- ContourOverlay での表示時のスケーリング問題

### 3. Vision Framework の制限
- iOS 17.0 の新しいAPIで、まだ安定していない可能性
- 代替手段として VNDetectHumanBodyPoseRequest の使用を検討

## 次回の修正で試すべきアプローチ

### 1. デバッグマスクの視覚的確認
```swift
debugSaveMask(pixelBuffer: maskedPixelBuffer)
```
保存されたマスク画像を確認し、実際にどのような形状が検出されているか確認

### 2. シンプルなバウンディングボックス
まず単純に人物の矩形領域を検出し、その後輪郭に拡張

### 3. 代替API の検討
- VNDetectHumanBodyPoseRequest
- Core ML を使用したカスタムセグメンテーション

### 4. 段階的なデバッグ
1. マスクの全ピクセルを可視化
2. エッジピクセルのみを表示
3. 輪郭追跡の各ステップを可視化

### 5. 既存の成功事例の調査
iPhoneの写真アプリの被写体抽出機能の実装方法を参考にする

## 重要な考慮事項
- 画像サイズ: 4032x3024 は大きいため、処理前のダウンサンプリングを検討
- パフォーマンス: エッジ検出で973,857個のピクセルは多すぎる可能性
- UI/UX: ユーザーが手動で輪郭を調整できるオプションの追加

## 参考リンク
- [Vision Framework Documentation](https://developer.apple.com/documentation/vision)
- [VNGenerateForegroundInstanceMaskRequest](https://developer.apple.com/documentation/vision/vngenerateforegroundinstancemaskrequest)
- [WWDC 2023 - Lift subjects from images in your app](https://developer.apple.com/videos/play/wwdc2023/10176/)

## 関連ファイル
- `/Users/kojok/Desktop/BodyLapse/BodyLapse/Services/BodyContourService.swift` - 輪郭検出サービス
- `/Users/kojok/Desktop/BodyLapse/BodyLapse/Views/Onboarding/ContourConfirmationView.swift` - 輪郭確認ビュー
- `/Users/kojok/Desktop/BodyLapse/BodyLapse/Views/Onboarding/OnboardingView.swift` - オンボーディングフロー

## デバッグコマンド
```bash
# ビルドコマンド
xcodebuild -project BodyLapse.xcodeproj -scheme BodyLapse -configuration Debug -sdk iphonesimulator build

# デバッグマスク画像の場所
/var/mobile/Containers/Data/Application/[APP_ID]/tmp/debug_mask_*.png
```