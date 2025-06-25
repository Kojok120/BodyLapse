# AdMob Setup Instructions for BodyLapse

## Overview
Google AdMob has been integrated into the BodyLapse app. The implementation shows ads only to free plan users:
- Banner ads at the bottom of Calendar, Compare, and Gallery screens
- Interstitial ad before video generation

## Setup Steps

### 1. Add Google Mobile Ads SDK
You need to add the Google Mobile Ads SDK to your Xcode project:

1. Open `BodyLapse.xcodeproj` in Xcode
2. Select the project in the navigator
3. Select the BodyLapse target
4. Go to the "General" tab
5. Scroll to "Frameworks, Libraries, and Embedded Content"
6. Click the "+" button
7. Search for and add the Google Mobile Ads SDK via Swift Package Manager:
   - Click "Add Package"
   - Enter: `https://github.com/googleads/swift-package-manager-google-mobile-ads`
   - Select the latest version
   - Add `GoogleMobileAds` package to your target

### 2. Update Info.plist
Add the following to your `Info.plist` file:

```xml
<key>GADApplicationIdentifier</key>
<string>YOUR_ADMOB_APP_ID</string>

<key>SKAdNetworkItems</key>
<array>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>cstr6suwn9.skadnetwork</string>
    </dict>
    <!-- Add more SKAdNetwork identifiers as needed -->
</array>
```

### 3. Update AdMob IDs
In `/BodyLapse/Services/AdMobService.swift`, replace the test ad unit IDs with your production IDs:

```swift
// Replace these with your actual AdMob ad unit IDs
var bannerAdUnitID: String {
    #if DEBUG
    return testBannerAdUnitID
    #else
    return "YOUR_PRODUCTION_BANNER_AD_UNIT_ID"  // Replace this
    #endif
}

var interstitialAdUnitID: String {
    #if DEBUG
    return testInterstitialAdUnitID
    #else
    return "YOUR_PRODUCTION_INTERSTITIAL_AD_UNIT_ID"  // Replace this
    #endif
}
```

### 4. Test Ad IDs (Currently in use)
- Banner: `ca-app-pub-3940256099942544/2934735716`
- Interstitial: `ca-app-pub-3940256099942544/4411468910`

These test IDs are safe to use during development and will show test ads.

## Implementation Details

### Banner Ads
- Automatically hidden for premium users
- Displayed at the bottom of Calendar, Compare, and Gallery screens
- Uses a reusable `BannerAdView` component and `withBannerAd()` modifier

### Interstitial Ads
- Shown before video generation for free users only
- Premium users skip the ad and go directly to video generation
- Preloaded when the app starts for better performance

### Code Structure
- `/Services/AdMobService.swift` - Main AdMob service singleton
- `/Views/Components/BannerAdView.swift` - Reusable banner ad component
- Integration points in Calendar, Compare, and Gallery views

## Testing
1. Run the app with test ad IDs to verify ad placement
2. Test with both free and premium accounts to ensure ads only show for free users
3. Verify interstitial ad shows before video generation for free users

## Important Notes
- Always use test ads during development
- Submit your app for AdMob review before going live
- Monitor ad performance and user experience
- Consider ad placement guidelines to avoid accidental clicks