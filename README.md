# BodyLapse - Transform Your Fitness Journey

<div align="center">
  <img src="BodyLapse/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" width="200" height="200" alt="BodyLapse Icon">
  
  **Track your fitness transformation with daily progress photos**
  
  [![iOS](https://img.shields.io/badge/iOS-17.0+-000000.svg?style=flat&logo=apple)](https://www.apple.com/ios/)
  [![Swift](https://img.shields.io/badge/Swift-5.9+-FA7343.svg?style=flat&logo=swift)](https://swift.org)
  [![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0+-0066FF.svg?style=flat)](https://developer.apple.com/xcode/swiftui/)
  [![License](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE)
  
  [Download on App Store](#) • [Privacy Policy](#privacy) • [Support](#support)
</div>

---

## 🎯 What is BodyLapse?

BodyLapse is a privacy-focused iOS app that helps you track your fitness journey through daily progress photos and time-lapse videos. Unlike other fitness apps, BodyLapse works completely offline - your photos never leave your device unless you explicitly share them.

### 📱 Key Features

- **📸 Daily Progress Photos** - Capture consistent photos with pose guidelines
- **🎬 Time-lapse Videos** - Create stunning transformation videos
- **🔒 Complete Privacy** - All data stays on your device
- **📊 Weight Tracking** - Monitor weight and body fat percentage (Premium)
- **📝 Daily Notes** - Add context to your journey
- **🌍 Multi-language** - English, Japanese, Spanish, and Korean

## 💎 Features Overview

### Core Features (Free)

#### 📸 Smart Photo Capture
- **Body Detection Guidelines** - AI-powered pose detection ensures consistent photos
- **Face Blur Privacy** - Automatically blur your face for privacy
- **Timer Options** - 3, 5, or 10-second timer for hands-free capture
- **Photo Import** - Import existing photos from your gallery
- **Daily Reminders** - Get notified if you haven't taken your photo by 7 PM

#### 📅 Progress Calendar
- **Visual Timeline** - See your transformation at a glance
- **Date Navigation** - Jump to any date to view photos
- **Progress Indicators** - Visual markers for photos and weight data
- **Time Period Views** - 7 days, 30 days, 3 months, 6 months, or 1 year
- **Daily Memos** - Add notes (up to 100 characters) to remember context

#### 🎬 Video Generation
- **Time-lapse Creation** - Turn your photos into transformation videos
- **Speed Control** - Slow, normal, or fast playback options
- **Quality Settings** - Standard (720p), High (1080p), or Ultra (4K)
- **Privacy Options** - Apply face blur to videos
- **Smart Navigation** - Auto-plays video after generation

#### 🖼️ Gallery Management
- **Organized Views** - Separate tabs for Videos and Photos
- **Bulk Operations** - Select multiple items to delete, save, or share
- **Date Display** - See when each photo/video was created
- **Easy Sharing** - Share directly to social media

#### 🆚 Before/After Comparison
- **Side-by-Side View** - Compare any two photos
- **Date Selection** - Choose specific dates to compare
- **Progress Metrics** - See weight/body fat changes (Premium)

### Premium Features ($4.99/month)

#### 📊 Advanced Tracking
- **Weight & Body Fat** - Track detailed body metrics
- **Interactive Charts** - Visualize progress over time
- **HealthKit Sync** - Automatic data synchronization
- **Unit Flexibility** - Switch between kg/lbs

#### 🏷️ Multiple Categories
- **4 Photo Categories** - Front, Back, Side, and Custom
- **Category Guidelines** - Separate pose guides for each angle
- **Filtered Videos** - Create category-specific time-lapses
- **Side-by-Side Videos** - Compare multiple angles simultaneously

#### 🎯 Premium Benefits
- **No Advertisements** - Clean, distraction-free experience
- **No Watermarks** - Professional-looking videos
### 🔐 Security & Privacy
- **Face ID/Touch ID** - Secure app access with biometrics
- **PIN Protection** - 4-digit passcode option
- **Local Storage** - Photos never leave your device
- **No Cloud Sync** - Complete offline functionality
- **Export Control** - You decide what to share and when

### 🌐 Localization

BodyLapse supports 4 languages:
- 🇺🇸 English
- 🇯🇵 Japanese (日本語)
- 🇪🇸 Spanish (Español)  
- 🇰🇷 Korean (한국어)

## 📱 App Screenshots

<div align="center">
  <table>
    <tr>
      <td align="center">
        <img src="screenshots/calendar.png" width="250" alt="Calendar View">
        <br><b>Calendar View</b>
      </td>
      <td align="center">
        <img src="screenshots/camera.png" width="250" alt="Camera Capture">
        <br><b>Camera with Guidelines</b>
      </td>
      <td align="center">
        <img src="screenshots/gallery.png" width="250" alt="Gallery">
        <br><b>Gallery</b>
      </td>
    </tr>
    <tr>
      <td align="center">
        <img src="screenshots/comparison.png" width="250" alt="Comparison">
        <br><b>Before/After</b>
      </td>
      <td align="center">
        <img src="screenshots/weight-chart.png" width="250" alt="Weight Chart">
        <br><b>Progress Charts</b>
      </td>
      <td align="center">
        <img src="screenshots/settings.png" width="250" alt="Settings">
        <br><b>Settings</b>
      </td>
    </tr>
  </table>
</div>

## 📦 Data Export Format

BodyLapse uses a custom `.bodylapse` file format for data export/import:

### File Structure
```
export_2025_01_08.bodylapse (ZIP archive)
├── metadata.json           # Export metadata
├── photos/                 # Photo files
│   ├── Front/             # Category folders
│   ├── Back/
│   └── Side/
├── videos/                # Generated videos
├── weight_data.json       # Weight/body fat entries
├── notes.json             # Daily memos
└── settings.json          # App preferences
```

### Metadata Format
```json
{
  "version": "1.0",
  "exportDate": "2025-01-08T10:30:00Z",
  "photoCount": 150,
  "videoCount": 5,
  "categories": ["Front", "Back", "Side"],
  "dateRange": {
    "start": "2024-01-01",
    "end": "2025-01-08"
  }
}
```

## 🔔 Notification System

### Automatic Daily Check
- **Check Time**: 7:00 PM (19:00) daily
- **Condition**: Notification sent only if no photo taken that day
- **Action**: Tap notification to open camera directly
- **Setup**: Permission requested during onboarding

### Notification Behavior
```swift
// Notification payload
{
  "title": "Time for your daily photo!",
  "body": "Track your progress with today's photo",
  "category": "DAILY_REMINDER",
  "userInfo": {
    "action": "open_camera"
  }
}
```

## 🏗️ Technical Architecture

### Technology Stack

| Component | Technology |
|-----------|------------|
| Language | Swift 5.9+ |
| UI Framework | SwiftUI |
| Architecture | MVVM |
| Minimum iOS | 17.0 |
| Image Processing | Vision Framework |
| Video Generation | AVFoundation |
| Health Data | HealthKit |
| Monetization | StoreKit 2 + AdMob |
| Authentication | LocalAuthentication |

### Project Structure

```
BodyLapse/
├── 📱 App/
│   ├── BodyLapseApp.swift      # App entry point
│   └── AppDelegate.swift        # App lifecycle
├── 📐 Models/
│   ├── Photo.swift              # Photo data model
│   ├── Video.swift              # Video data model
│   ├── WeightEntry.swift        # Weight tracking
│   └── PhotoCategory.swift      # Category management
├── 🎨 Views/
│   ├── Calendar/                # Progress tracking
│   ├── Camera/                  # Photo capture
│   ├── Gallery/                 # Media browser
│   ├── Comparison/              # Before/after
│   └── Settings/                # App configuration
├── 🧠 ViewModels/
│   └── [Feature]ViewModel.swift # Business logic
├── ⚙️ Services/
│   ├── PhotoStorageService.swift     # Photo management
│   ├── VideoGenerationService.swift  # Video creation
│   ├── BodyContourService.swift      # Pose detection
│   └── HealthKitService.swift        # Health integration
└── 🌍 Resources/
    ├── Localizable.strings      # Translations
    └── Assets.xcassets          # Images & colors
```


## 🚦 Current Status

### ✅ Completed Features
- Core photo capture and storage system
- Body detection and pose guidelines
- Calendar view with progress tracking
- Time-lapse video generation
- Gallery with bulk operations
- Weight and body fat tracking
- Multiple photo categories
- Import/Export functionality
- Daily memo system
- Complete localization (4 languages)
- Premium subscription system
- Ad integration (AdMob)
- HealthKit integration
- Face ID/Touch ID authentication
- Comprehensive onboarding flow



## 🙏 Acknowledgments

- Vision Framework for body detection
- SwiftUI for modern UI development
- The fitness community for inspiration

---

<div align="center">
  <b>Transform your body, one photo at a time.</b>
  
  Made with ❤️ for the fitness community
</div>