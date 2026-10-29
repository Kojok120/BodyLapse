# Repository Guidelines

このファイルは Codex と Claude の両方が読む。`CLAUDE.md` は `@AGENTS.md` を import するスタブなので、指示の編集は AGENTS.md だけで行う。

## Project Structure & Module Organization
BodyLapse/ contains SwiftUI app sources organized by feature: Models/ define data types, ViewModels/ hold observable state, Views/ is grouped by feature directories, Services/ encapsulate persistence, media, and integrations, while Utilities/ stores shared helpers. Assets.xcassets and localized strings live beside the entry points (BodyLapseApp.swift, AppDelegate.swift). Tests sit in BodyLapseTests/ for unit coverage and BodyLapseUITests/ for UI flows; keep fixtures next to the tests that use them. Third-party dependencies (Google Mobile Ads, OpenCV) come from Swift Package Manager references in the Xcode project; there is no CocoaPods setup.

## Build, Test, and Development Commands
For IDE work open `BodyLapse.xcodeproj` (Xcode resolves the Swift packages). CLI builds use `xcodebuild -project BodyLapse.xcodeproj -scheme BodyLapse -destination 'platform=iOS Simulator,name=iPhone 16' build`. Run unit tests with the same command, adding `-only-testing:BodyLapseTests` and replacing `build` with `test` (this is what PR CI runs). Generate localized previews through Xcode previews; simulator snapshots go under `screenshots/` when documenting UI.

## Coding Style & Naming Conventions
Adopt Swift 5.9 idioms: indent with four spaces, prefer `struct` over classes unless reference semantics are required, and mark reference types `final` when possible. Name types and files UpperCamelCase (e.g., `CalendarView.swift`), properties/functions lowerCamelCase, and enums with singular cases. Group logic using `// MARK:` headings and keep SwiftUI view modifiers vertically aligned. Localized keys belong in `*.lproj/Localizable.strings` with matching developer comments.

## Testing Guidelines
Unit tests use XCTest in `BodyLapseTests`; name methods `test<Feature><Behavior>()` and mirror source namespaces. UI flows belong in `BodyLapseUITests`, relying on stable accessibility identifiers (see `SimpleCameraView`). Run `xcodebuild … test` before every PR and update snapshots or test data under version control. Add regression tests whenever modifying Services/ or ViewModels/ logic that hits persistence or network-like boundaries.

## Commit & Pull Request Guidelines
Commits in this repo are narrative and impact-focused, often written in Japanese; follow that pattern by summarizing the change, why it matters, and any user-facing effect in one sentence. Keep commits scoped to a single concern. Pull requests must describe the motivation, list key changes, note testing performed, and attach before/after media for UI updates. Reference related Jira or GitHub issues when available and flag configuration changes that require App Store Connect or entitlement updates.

## 設計の前提

- コア機能（撮影・保存・動画生成・顔ぼかし）は端末内で処理し、自前のサーバーへ送らない。写真と動画はアプリの Documents に置き、端末の外へ出るのはユーザーが共有したときと Pro の iCloud バックアップ（ユーザー自身の iCloud）だけにする
- 永続化は設定が UserDefaults、写真・動画・体重・メモが Documents 配下のファイル（Core Data / SwiftData は使っていない）
- iPhone 専用（iPad 非対応・全画面）
- 作業の後は必ずビルドし、成功を確かめてから終える

## 課金と機能の線引き

- ティアは Free（広告あり）/ Standard（広告削除のみ。`com.J.BodyLapse.premium.monthly`）/ Pro（iCloud 自動バックアップ＋共有画像の透かしなし＋広告なし。`com.J.BodyLapse.pro.monthly` / `.pro.yearly`）。判定は `SubscriptionManagerService` の `isPremium`（Standard 以上）と `isPro` で行う
- 公開済みの無料機能（体重記録・チャート・タイムラプス動画の透かしなし など）を後から有料にしない。透かしの再導入やゲートの付け直しを提案しない
- ストリーク・実績・進捗インサイト・目標は全ユーザー無料に保つ（続けるための機能なので壁にしない）
- Pro の価値は新しい機能を足して作る。未実装の機能（「高度な動画」など）をペイウォールや説明文で訴求しない
- 文脈ペイウォールは種類ごとに原則 1 回きり（撮影 30 日達成時のクラウド誘導と、初回の比較共有時の透かし誘導。`PaywallPromptManager`）。新しく足すときも同じ作法でしつこくしない
- Pro の iCloud バックアップは CloudKit のプライベート DB に、動画を含めて 1 日 1 回・Wi-Fi 接続時に自動で上げる（`CloudBackupService`）
- App Store Connect のサブスクグループでは Pro（月額・年額）がレベル 1、Standard がレベル 2（アップグレードの按分が効く順）。商品を足すときもこの順を崩さない

## 人物ビジュアル（オンボーディング・ストア画像・LP）

- 人物はアプリアイコンと同じ全身黄色の 3D 人型で描く。性別が分からない造形、大人の頭身、服は同じ黄色の素材のタンクトップと短パン
- 実写調・リアル寄りの体型表現・男女の 3D キャラクター・手描き SVG のイラストは使わない（体型はセンシティブなため）。`bodylapse-marketing/` にある古いマーケ素材も人物の参考にしない
- 日数ごとの変化の絵は、1 日目の画像を元に Gemini の画像モデルで編集して作る。変化は「X%」のような割合でなく段階の描写で指示する（割合で書くと途中を飛ばしていきなり引き締まる）
- 今の素材は `BodyLapse/Assets.xcassets` の `OnboardingFigureDay01` / `30` / `60` / `90`。元画像と生成スクリプトは gitignore 済みの `bodylapse-marketing/onboarding-yellow-figure/` にあり、クローンには含まれない
