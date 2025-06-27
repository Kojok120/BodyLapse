# BodyLapse - iOS Fitness Progress Tracking App

## Project Overview

BodyLapse is an iOS app that helps users track their fitness progress by taking daily photos and creating time-lapse videos of their body transformation. The app operates completely offline, ensuring user privacy and data security.

## Core Features

### 1. Photo Capture & Storage
- Daily photo capture with pose guidelines
- Red outline overlay from initial setup to maintain consistent positioning
- Photos stored locally in app's Documents directory
- One-tap face blur functionality

### 2. Time-lapse Video Generation
- Select date range for video creation
- Generate time-lapse videos on-device
- Export and share functionality

### 3. Initial Setup
- Goal setting screen on first launch
- Pose guideline setup using body detection
- Notification time preference

### 4. Comparison & Sharing
- Before/after comparison view
- Face blur options (none/light/heavy)
- Direct social media sharing

### 5. Data Tracking (Premium)
- Weight and body fat percentage logging
- Daily data visualization with photos

## Technical Architecture

### Technology Stack
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Target iOS Version**: iOS 17.0 (for advanced Vision framework features)
- **Architecture Pattern**: MVVM
- **Data Storage**: Local file system + UserDefaults
- **Image Processing**: Vision framework for body/face detection
- **Video Generation**: AVFoundation
- **Ads**: Google Mobile Ads SDK v12
- **In-App Purchases**: StoreKit 2
- **Health Data**: HealthKit integration for weight/body fat syncing
- **Authentication**: LocalAuthentication for Face ID/Touch ID

### Key Dependencies
- Vision framework (body/face detection)
- AVFoundation (video generation)
- PhotosUI (image handling)
- UserNotifications (daily reminders)
- GoogleMobileAds (ad monetization)
- StoreKit (in-app purchases)
- Charts (weight tracking visualization)
- HealthKit (weight and body fat percentage syncing)
- LocalAuthentication (Face ID/Touch ID support)

## Project Structure

```
BodyLapse/
├── BodyLapseApp.swift
├── AppDelegate.swift
├── Models/
│   ├── Photo.swift
│   ├── Video.swift
│   ├── UserSettings.swift
│   ├── Guideline.swift
│   ├── WeightEntry.swift
│   └── PremiumFeature.swift
├── Views/
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   └── ContourConfirmationView.swift
│   ├── Authentication/
│   │   ├── AuthenticationView.swift
│   │   └── PasswordSetupView.swift
│   ├── Calendar/
│   │   ├── CalendarView.swift
│   │   ├── CalendarPopupView.swift
│   │   └── InteractiveWeightChartView.swift
│   ├── Camera/
│   │   ├── CameraView.swift
│   │   └── CameraPreviewView.swift
│   ├── Gallery/
│   │   ├── GalleryView.swift
│   │   ├── VideoDetailView.swift
│   │   └── PhotoGridView.swift
│   ├── Comparison/
│   │   └── ComparisonView.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── NotificationSettingsView.swift
│   │   ├── PremiumView.swift
│   │   └── ResetGuidelineView.swift
│   ├── Components/
│   │   ├── BannerAdView.swift
│   │   ├── WeightTrackingView.swift
│   │   └── ShareSheet.swift
│   └── MainTabView.swift
├── ViewModels/
│   ├── CameraViewModel.swift
│   ├── CalendarViewModel.swift
│   ├── GalleryViewModel.swift
│   ├── ComparisonViewModel.swift
│   ├── WeightTrackingViewModel.swift
│   └── PremiumViewModel.swift
├── Services/
│   ├── PhotoStorageService.swift
│   ├── VideoGenerationService.swift
│   ├── VideoStorageService.swift
│   ├── BodyContourService.swift
│   ├── FaceBlurService.swift
│   ├── NotificationService.swift
│   ├── AdMobService.swift
│   ├── WeightStorageService.swift
│   ├── GuidelineStorageService.swift
│   ├── HealthKitService.swift
│   ├── AuthenticationService.swift
│   └── StoreManager.swift
└── Resources/
    ├── Assets.xcassets
    ├── Info.plist
    └── BodyLapse.entitlements
```

## Implementation Status

### ✅ Completed Features

#### Phase 1: Foundation
- Project setup with tab-based navigation
- Camera integration with photo capture and camera switching
- Local photo storage with metadata support
- Calendar view with photo browsing and time period selection

#### Phase 2: Core Features  
- Body detection with pose guidelines (red overlay)
- Camera overlay with guideline display
- Face blur functionality (privacy feature)
- Photo comparison view with date selection

#### Phase 3: Video Generation
- Time-lapse video generation with customizable speed/quality
- Video export and sharing functionality  
- Watermark overlay for free users
- Auto-navigation to Gallery after generation

#### Phase 4: Premium Features
- Weight/body fat tracking with data entry
- Interactive weight charts with multiple time ranges
- StoreKit integration for premium subscriptions
- Google AdMob integration (banner and interstitial ads)

#### Phase 5: Polish & Enhancements
- Daily reminder notifications
- Photo import functionality
- Swipe navigation in Gallery (Videos ↔ Photos)
- Auto-navigation from Camera to Calendar
- iPhone-only configuration
- Settings for units, notifications, and debug options

#### Phase 6: Health & Security (December 2025)
- HealthKit integration for automatic weight/body fat syncing
- Face ID/Touch ID authentication support
- Passcode authentication option
- Complete 3-step onboarding flow (goals, baseline photo, security)
- Fixed onboarding camera retake bug
- Fixed weight/body fat display layout issues

#### Phase 7: UI Enhancements & Features (December 27, 2025)
- Body guideline reset feature in Settings
- Enhanced CalendarView with improved layout and date selection
- Increased face blur effect intensity
- Camera improvements (default to back camera, save camera position with guidelines)
- UI refinements for weight/body fat charts

### 🚧 Pending Tasks
- App Store submission preparation (icons, screenshots, descriptions)
- Privacy policy and terms of service
- Additional UI polish and animations
- Performance optimization for large photo collections
- Localization support

## UI/UX Design Principles

### Design System
- **Primary Color**: #007AFF (iOS Blue) or custom brand color
- **Secondary Color**: #34C759 (Success Green)
- **Background**: System backgrounds (adaptive dark/light)
- **Typography**: SF Pro Display/Text
- **Spacing**: 8pt grid system

### Key Screens
1. **Home Screen**: Clean grid of recent photos with prominent camera button
2. **Camera Screen**: Full-screen camera with guideline overlay
3. **Calendar View**: Month view with photo thumbnails
4. **Comparison View**: Split-screen photo comparison
5. **Settings**: Minimal options with clear sections

## Data Models

### Photo Model
```swift
struct Photo {
    let id: UUID
    let date: Date
    let imagePath: String
    let thumbnailPath: String
    let weight: Double?
    let bodyFat: Double?
}
```

### Pose Guideline Model
```swift
struct PoseGuideline {
    let points: [CGPoint]
    let bodyRect: CGRect
    let scale: CGFloat
}
```

## Privacy & Security

- All photos stored in app's private Documents directory
- No network requests for core functionality
- Face blur processing done on-device
- Face ID/Touch ID authentication support
- Passcode authentication option
- HealthKit data stays on device unless user explicitly syncs
- No user data leaves device without explicit user action

## Monetization

### Free Plan
- Full photo tracking and video generation
- Banner ads (Google AdMob v12)
- Watermark on exported videos
- Interstitial ads before video generation

### Premium Plan ($4.99/month)
- No ads
- No watermark
- Weight/body fat tracking with interactive charts
- Body fat percentage tracking
- HealthKit integration for automatic data syncing

## Development Notes

### Critical Implementation Details
1. Use `UIImagePickerController` or `AVCaptureSession` for camera
2. Store photos as JPEG with 80% quality for balance
3. Generate thumbnails immediately after capture
4. Use background queue for video generation
5. Implement proper memory management for large photo sets

### Performance Considerations
- Lazy load images in calendar view
- Cache thumbnails aggressively
- Limit video generation to 365 photos maximum
- Use metal shaders for video effects if needed

## Testing Strategy

1. Unit tests for data models and services
2. UI tests for critical user flows
3. Performance tests for video generation
4. Manual testing on various iPhone models
5. TestFlight beta with fitness enthusiasts

## App Store Optimization

### Keywords
- fitness tracker, body transformation, progress photos, workout diary, muscle gain

### Description Focus
- Privacy-first approach
- Offline functionality
- Visual progress tracking
- Simple daily habit

## Recent Development Notes

### Key Navigation Flows
1. **Photo Capture → Calendar**: After taking a photo, automatically navigates to Calendar view showing today's date
2. **Video Generation → Gallery**: After generating video, automatically navigates to Gallery and plays the new video
3. **Gallery Navigation**: Swipe left/right between Videos and Photos sections

### Ad Implementation
- **Banner Ads**: Display at bottom of Calendar, Compare, and Gallery screens for free users only
- **Interstitial Ads**: Show before video generation starts for free users
- **Premium Detection**: Uses UserSettingsManager.shared for consistent premium status checking

### Device Support
- **iPhone Only**: App is configured for iPhone-only usage (UIDeviceFamily = 1)
- **Orientation**: Portrait only with UIRequiresFullScreen enabled
- **Image Orientation**: Fixed orientation handling for proper video generation

### Known Issues to Address
1. Add all required app icon sizes for App Store submission
2. Complete privacy policy and terms of service documents

### Recent Bug Fixes (December 2025)
1. **Onboarding Camera Retake**: Fixed issue where capture button became unresponsive after pressing retake button
   - Solution: Properly managed camera controller lifecycle with async state updates
2. **Weight/Body Fat Display**: Fixed layout issues causing text to wrap incorrectly
   - Solution: Added minWidth constraints and line limits to ensure consistent layout

