# BodyLapse App Store Submission Roadmap

## Overview
This document provides a comprehensive roadmap for preparing the BodyLapse iOS app for App Store submission. All tasks are organized by priority and dependency to ensure a smooth submission process.

## 🚨 Critical Pre-Submission Tasks

### 1. AdMob Production Setup ⭐️ HIGHEST PRIORITY
**Current Status**: App uses test Ad IDs only  
**Required Actions**:
1. Create/Access your AdMob account at https://admob.google.com
2. Create new app in AdMob dashboard for "BodyLapse"
3. Generate production Ad Unit IDs:
   - Banner Ad Unit ID (for Calendar, Compare, Gallery views)
   - Interstitial Ad Unit ID (for video generation)
4. Update `/Services/AdMobService.swift`:
   - Replace `"YOUR_PRODUCTION_BANNER_AD_UNIT_ID"` with actual Banner ID
   - Replace `"YOUR_PRODUCTION_INTERSTITIAL_AD_UNIT_ID"` with actual Interstitial ID
5. Update Info.plist with your AdMob App ID:
   - Replace test ID `ca-app-pub-3940256099942544~1458002511` with production ID
6. **IMPORTANT**: Test thoroughly with production IDs before submission

### 2. App Icons Generation ⭐️ HIGHEST PRIORITY
**Current Status**: Only 1024x1024 icon exists  
**Required Actions**:
1. Generate all required iPhone icon sizes:
   - 20x20 (2x, 3x) - Notification icons
   - 29x29 (2x, 3x) - Settings icons
   - 40x40 (2x, 3x) - Spotlight icons
   - 60x60 (2x, 3x) - App icons
   - 1024x1024 - App Store icon
2. Remove Mac-specific icon entries from `AppIcon.appiconset/Contents.json`
3. Use tools like IconSet Creator or Bakery to generate all sizes
4. Ensure icons follow Apple's design guidelines (no transparency, no rounded corners)

### 3. Launch Screen Creation ⭐️ HIGHEST PRIORITY
**Current Status**: No launch screen exists  
**Required Actions**:
1. Create `LaunchScreen.storyboard` in Xcode
2. Design options:
   - Simple design with app logo centered
   - Background color matching your app's theme
   - Avoid text that needs localization
3. Add to project and set in Target Settings > General > Launch Screen
4. Test on all iPhone sizes to ensure proper scaling

### 4. Privacy Manifest (PrivacyInfo.xcprivacy) ⭐️ HIGH PRIORITY
**Current Status**: Missing required privacy manifest  
**Required Actions**:
1. Create `PrivacyInfo.xcprivacy` file in Xcode (File > New > File > Resource > App Privacy)
2. Declare API usage reasons for:
   - File timestamp APIs (for photo metadata)
   - User defaults (for settings storage)
   - Photo library access
   - Camera access
3. Reference Apple's documentation for required reason codes
4. Add to app target in Xcode

### 5. Update Privacy Policy Contact Information ⭐️ HIGH PRIORITY
**Current Status**: Contains placeholder text  
**Required Actions**:
1. Edit `privacy_policy.html`:
   - Replace `[Your Contact Email]` with actual support email
   - Replace `[Your Website URL]` with actual website/support URL
   - Update "Last updated" date
2. Host privacy policy online for App Store submission
3. Ensure privacy policy URL is accessible

### 6. Create Terms of Service ⭐️ HIGH PRIORITY
**Current Status**: No terms of service document  
**Required Actions**:
1. Create `terms_of_service.html` based on privacy policy template
2. Include sections for:
   - Subscription terms and auto-renewal
   - Acceptable use policy
   - Content ownership
   - Limitation of liability
   - Cancellation policy
3. Host online alongside privacy policy
4. Add link in Settings view

## 📱 App Store Connect Configuration

### 7. Create App in App Store Connect
**Required Actions**:
1. Log in to App Store Connect
2. Create new app with bundle ID: `com.J.BodyLapse`
3. Fill in app information:
   - App name: "BodyLapse"
   - Primary language: English
   - Category: Health & Fitness
   - Secondary category: Photo & Video

### 8. Configure In-App Purchases
**Reference**: Follow `AppStoreConnect_Subscription_Setup.md`  
**Required Actions**:
1. Create subscription group: "BodyLapse Premium"
2. Create auto-renewable subscription:
   - Product ID: `com.J.BodyLapse.premium.monthly`
   - Price: $4.99/month
   - Description: "Remove ads, watermarks, and track weight"
3. Configure subscription benefits and screenshots
4. Submit for review

### 9. Update StoreKit Configuration
**Current Status**: Contains placeholder values  
**Required Actions**:
1. After creating app in App Store Connect, update `BodyLapse.storekit`:
   - Replace `_applicationInternalID: "0"` with actual App ID
   - Replace `_developerTeamID: "0"` with your Team ID
2. Sync with App Store Connect to verify configuration

## 🧹 Code Cleanup Tasks

### 10. Remove Debug Settings
**Required Actions**:
1. Remove `DebugSettingsView.swift` from project
2. In `SettingsView.swift`:
   - Remove the debug section (lines with `#if DEBUG`)
   - Remove import and reference to DebugSettingsView
3. Search project for other `#if DEBUG` blocks and evaluate each:
   - Keep debug-only test ad IDs (they're properly gated)
   - Remove any debug UI elements
   - Keep logging that's useful for crash reporting

### 11. Clean Up Development Code
**Required Actions**:
1. Remove or comment out any `print()` statements in production code
2. Ensure no hardcoded test data remains
3. Verify all TODO comments are addressed or removed
4. Remove any unused frameworks (e.g., opencv2.framework mentioned in CLAUDE.md)

## 📸 App Store Assets

### 12. Prepare Screenshots
**Required Sizes**: 
- 6.7" (iPhone 15 Pro Max): 1290 x 2796
- 6.5" (iPhone 14 Plus): 1284 x 2778  
- 5.5" (iPhone 8 Plus): 1242 x 2208

**Recommended Screenshots**:
1. Onboarding/Welcome screen
2. Camera view with pose guidelines
3. Calendar view showing progress
4. Time-lapse video generation
5. Before/after comparison view

**Tips**:
- Show the app in use with sample data
- Highlight premium features
- Use device frames for professional look
- Consider using tools like Sketch, Figma, or Screenshot Creator

### 13. Write App Store Description
**Required Sections**:
1. **Short description** (up to 170 characters):
   "Track your fitness journey with daily photos and create stunning transformation time-lapse videos"

2. **Long description** (up to 4000 characters):
   - Introduce the app's purpose
   - List key features
   - Explain privacy-first approach
   - Mention premium benefits
   - Include call-to-action

3. **Keywords** (up to 100 characters):
   "fitness,progress,body,transformation,time-lapse,weight,tracker,before,after,workout"

4. **What's New** (for version 1.0):
   "Initial release of BodyLapse - Your personal fitness transformation tracker"

## ✅ Final Testing Checklist

### 14. Pre-Submission Testing
1. **Functional Testing**:
   - [ ] Test with production AdMob IDs
   - [ ] Verify subscription purchase flow
   - [ ] Test all premium features unlock correctly
   - [ ] Verify ads don't show for premium users
   - [ ] Test on minimum iOS version (17.0)

2. **Device Testing**:
   - [ ] Test on various iPhone models
   - [ ] Test in different orientations
   - [ ] Test with different language settings
   - [ ] Test in low storage conditions

3. **Privacy & Permissions**:
   - [ ] Test permission requests appear correctly
   - [ ] Verify app works when permissions are denied
   - [ ] Test Face ID/Touch ID authentication

4. **Content Testing**:
   - [ ] Verify no placeholder text remains
   - [ ] Check all images load correctly
   - [ ] Ensure watermark appears for free users
   - [ ] Test video generation with many photos

## 📋 Submission Checklist

### 15. Final App Store Connect Setup
- [ ] Upload build via Xcode
- [ ] Fill in all app information fields
- [ ] Upload all screenshots
- [ ] Set up pricing (Free with In-App Purchases)
- [ ] Configure age rating (likely 4+)
- [ ] Add privacy policy URL
- [ ] Add support URL
- [ ] Add marketing URL (optional)

### 16. Version Information
- [ ] Decide on version number (recommend keeping 1.0)
- [ ] Update build number if needed
- [ ] Prepare release notes

### 17. Review Information
- [ ] Provide demo account if needed (not required for this app)
- [ ] Add notes for reviewer about premium features
- [ ] Specify that app works completely offline

## 🚀 Post-Submission Tasks

### 18. Monitor Review Process
- [ ] Check for any reviewer feedback
- [ ] Be prepared to respond quickly to issues
- [ ] Have fixes ready for common rejection reasons

### 19. Prepare for Launch
- [ ] Plan announcement strategy
- [ ] Set up customer support channel
- [ ] Monitor crash reports and user feedback
- [ ] Prepare first update with user-requested features

## ⏱ Estimated Timeline

**Day 1-2**: Critical tasks (AdMob, Icons, Launch Screen, Privacy)  
**Day 3**: App Store Connect setup and subscription configuration  
**Day 4**: Code cleanup and testing  
**Day 5**: Screenshot creation and description writing  
**Day 6**: Final testing and submission  

## 🎯 Priority Order

1. **Must Do Before Any Submission**:
   - AdMob production IDs
   - App icons
   - Launch screen
   - Privacy manifest
   - Privacy policy contact info
   - Terms of service

2. **Should Do for Professional Submission**:
   - Remove debug UI
   - Clean up code
   - Thorough testing
   - Quality screenshots

3. **Can Do After Submission**:
   - Additional marketing materials
   - Website creation
   - Social media presence

## 📝 Notes

- Keep the opencv2.framework removal note from CLAUDE.md in mind
- The app is already localized for multiple languages which is a plus
- The subscription implementation is complete and follows StoreKit 2 best practices
- Consider setting up TestFlight for beta testing before public release

This roadmap ensures your BodyLapse app meets all App Store requirements and presents professionally to reviewers and users alike.