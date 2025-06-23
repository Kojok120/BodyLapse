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
- **Minimum iOS Version**: iOS 16.0
- **Architecture Pattern**: MVVM
- **Data Storage**: Local file system + UserDefaults/Core Data
- **Image Processing**: Vision framework for body detection
- **Video Generation**: AVFoundation

### Key Dependencies
- Vision framework (body/face detection)
- AVFoundation (video generation)
- PhotosUI (image handling)
- UserNotifications (daily reminders)

## Project Structure

```
BodyLapse/
├── App/
│   ├── BodyLapseApp.swift
│   └── AppDelegate.swift
├── Models/
│   ├── Photo.swift
│   ├── UserProfile.swift
│   ├── PoseGuideline.swift
│   └── ProgressData.swift
├── Views/
│   ├── Onboarding/
│   │   ├── WelcomeView.swift
│   │   ├── GoalSettingView.swift
│   │   └── PoseSetupView.swift
│   ├── Main/
│   │   ├── HomeView.swift
│   │   ├── CameraView.swift
│   │   ├── CalendarView.swift
│   │   └── SettingsView.swift
│   ├── Comparison/
│   │   └── ComparisonView.swift
│   └── Components/
│       ├── CameraOverlay.swift
│       └── ShareSheet.swift
├── ViewModels/
│   ├── CameraViewModel.swift
│   ├── CalendarViewModel.swift
│   └── VideoGeneratorViewModel.swift
├── Services/
│   ├── PhotoStorageService.swift
│   ├── VideoGeneratorService.swift
│   ├── BodyDetectionService.swift
│   ├── FaceBlurService.swift
│   └── NotificationService.swift
├── Utils/
│   ├── Constants.swift
│   ├── Extensions/
│   └── Helpers/
└── Resources/
    ├── Assets.xcassets
    └── Localizable.strings
```

## Implementation Plan

### Phase 1: Foundation (Week 1-2)
1. Project setup and basic navigation structure
2. Camera integration with basic photo capture
3. Local photo storage system
4. Basic calendar view for photo browsing

### Phase 2: Core Features (Week 3-4)
1. Body detection and pose guideline system
2. Camera overlay with guideline display
3. Face detection and blur functionality
4. Photo comparison view

### Phase 3: Video Generation (Week 5-6)
1. Time-lapse video generation from photos
2. Video export and sharing functionality
3. Watermark overlay for free plan

### Phase 4: Premium Features (Week 7)
1. Weight/body fat tracking
2. Data visualization
3. In-app purchase integration
4. Ad integration for free plan

### Phase 5: Polish (Week 8)
1. Notification system
2. UI/UX refinements
3. Performance optimization
4. Testing and bug fixes

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
- Option to enable FaceID/TouchID for app access

## Monetization

### Free Plan
- Full photo tracking and video generation
- Banner ads
- Watermark on exported videos
- 30-day premium trial

### Premium Plan ($4.99/month)
- No ads
- No watermark
- Weight/body fat tracking
- Advanced analytics

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

