# Repository Guidelines

## Project Structure & Module Organization
BodyLapse/ contains SwiftUI app sources organized by feature: Models/ define data types, ViewModels/ hold observable state, Views/ is grouped by feature directories, Services/ encapsulate persistence, media, and integrations, while Utilities/ stores shared helpers. Assets.xcassets and localized strings live beside the entry points (BodyLapseApp.swift, AppDelegate.swift). Tests sit in BodyLapseTests/ for unit coverage and BodyLapseUITests/ for UI flows; keep fixtures next to the tests that use them. CocoaPods output resides in Pods/ and should not be edited manually.

## Build, Test, and Development Commands
Run `pod install` after dependency updates to refresh Pods/. For IDE work open `BodyLapse.xcworkspace`. CLI builds use `xcodebuild -workspace BodyLapse.xcworkspace -scheme BodyLapse -destination 'platform=iOS Simulator,name=iPhone 15' build`. Run tests with the same command replacing `build` with `test`. Generate localized previews through Xcode previews; simulator snapshots go under `screenshots/` when documenting UI.

## Coding Style & Naming Conventions
Adopt Swift 5.9 idioms: indent with four spaces, prefer `struct` over classes unless reference semantics are required, and mark reference types `final` when possible. Name types and files UpperCamelCase (e.g., `CalendarView.swift`), properties/functions lowerCamelCase, and enums with singular cases. Group logic using `// MARK:` headings and keep SwiftUI view modifiers vertically aligned. Localized keys belong in `*.lproj/Localizable.strings` with matching developer comments.

## Testing Guidelines
Unit tests use XCTest in `BodyLapseTests`; name methods `test<Feature><Behavior>()` and mirror source namespaces. UI flows belong in `BodyLapseUITests`, relying on stable accessibility identifiers (see `SimpleCameraView`). Run `xcodebuild … test` before every PR and update snapshots or test data under version control. Add regression tests whenever modifying Services/ or ViewModels/ logic that hits persistence or network-like boundaries.

## Commit & Pull Request Guidelines
Commits in this repo are narrative and impact-focused, often written in Japanese; follow that pattern by summarizing the change, why it matters, and any user-facing effect in one sentence. Keep commits scoped to a single concern. Pull requests must describe the motivation, list key changes, note testing performed, and attach before/after media for UI updates. Reference related Jira or GitHub issues when available and flag configuration changes that require App Store Connect or entitlement updates.
