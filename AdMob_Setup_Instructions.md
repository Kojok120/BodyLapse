# AdMob Setup Instructions for BodyLapse

## Overview
Google AdMob has been integrated into the BodyLapse app. The implementation shows ads only to free plan users:
- Banner ads at the bottom of Calendar, Compare, and Gallery screens
- Interstitial ad before video generation

## Getting AdMob IDs

### 1. Create AdMob Account
1. Go to [https://admob.google.com/](https://admob.google.com/)
2. Sign in with your Google account
3. Accept the terms and conditions

### 2. Register Your App
1. Click "Apps" in the sidebar
2. Click "ADD APP"
3. Select "iOS" platform
4. Enter your app details:
   - App name: BodyLapse
   - User metrics: Choose based on your preference
5. Click "ADD" to create your app
6. You'll receive your **AdMob App ID** (format: `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`)

### 3. Create Ad Units

#### Banner Ad Unit:
1. In your app dashboard, click "Ad units"
2. Click "ADD AD UNIT"
3. Select "Banner"
4. Configure:
   - Ad unit name: `BodyLapse Banner`
   - Advanced settings (optional): Keep defaults
5. Click "CREATE AD UNIT"
6. Copy the **Banner Ad Unit ID** (format: `ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ`)

#### Interstitial Ad Unit:
1. Click "ADD AD UNIT" again
2. Select "Interstitial"
3. Configure:
   - Ad unit name: `BodyLapse Interstitial`
   - Frequency capping: Recommended to set limits (e.g., 1 impression per user per hour)
4. Click "CREATE AD UNIT"
5. Copy the **Interstitial Ad Unit ID**

### 4. Test Ad IDs
During development, always use test ad IDs to avoid policy violations:

**Test App ID:** `ca-app-pub-3940256099942544~1458002511`

**Test Ad Unit IDs:**
- Banner: `ca-app-pub-3940256099942544/2934735716`
- Interstitial: `ca-app-pub-3940256099942544/4411468910`

These test IDs are provided by Google and safe to use during development.

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

**Important:** Replace `YOUR_ADMOB_APP_ID` with the actual App ID from your AdMob account (format: `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`)

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

### Development Best Practices
- **Always use test ads during development** to avoid invalid traffic
- Test on real devices when possible
- Enable test devices in AdMob console for your development devices

### Before Going Live
1. **Replace all test IDs** with production IDs
2. **Submit for AdMob review** if required
3. **Test thoroughly** with production ads on TestFlight
4. **Monitor initial performance** after launch

### Ad Policy Guidelines
- Avoid placing ads too close to interactive elements
- Don't encourage users to click ads
- Follow [AdMob policies](https://support.google.com/admob/answer/6128543)
- Respect user experience - don't show too many ads

### Troubleshooting
- If ads don't show: Check console logs for error messages
- Common issues:
  - Missing Info.plist configuration
  - Invalid ad unit IDs
  - Network connectivity issues
  - Ad serving limits for new accounts

### Revenue Optimization Tips
- Monitor eCPM and fill rates
- Consider mediation for better fill rates
- A/B test ad placements
- Use adaptive banners for better performance across devices