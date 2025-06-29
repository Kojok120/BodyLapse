# Multi-Language Localization Setup for BodyLapse

## Overview
BodyLapse now supports multiple languages:
- English (en) - Default
- Japanese (ja)
- Korean (ko)
- Spanish (es)

## Implementation Details

### Files Created

1. **Localizable.strings files**:
   - `BodyLapse/en.lproj/Localizable.strings` - English translations
   - `BodyLapse/ja.lproj/Localizable.strings` - Japanese translations
   - `BodyLapse/ko.lproj/Localizable.strings` - Korean translations
   - `BodyLapse/es.lproj/Localizable.strings` - Spanish translations

2. **LanguageManager Service**:
   - `BodyLapse/Services/LanguageManager.swift` - Handles language switching and management

3. **Updated Views**:
   - All views have been updated to use localized strings with `.localized` extension

## Manual Xcode Configuration Required

### 1. Add Localization Files to Project

1. Open `BodyLapse.xcodeproj` in Xcode
2. Right-click on the BodyLapse folder in the project navigator
3. Select "Add Files to BodyLapse..."
4. Navigate to each localization folder and add the Localizable.strings files:
   - `en.lproj/Localizable.strings`
   - `ja.lproj/Localizable.strings`
   - `ko.lproj/Localizable.strings`
   - `es.lproj/Localizable.strings`
5. Make sure "Copy items if needed" is unchecked (files are already in place)
6. Ensure target membership is checked for BodyLapse

### 2. Configure Project Localizations

1. Select the project file (BodyLapse) in the navigator
2. Select the project (not the target) in the editor
3. Go to the "Info" tab
4. Under "Localizations", click the "+" button to add:
   - Japanese (ja)
   - Korean (ko)
   - Spanish (es)
5. Make sure English is set as the development language

### 3. Add LanguageManager to Build

1. Right-click on the Services folder in Xcode
2. Select "Add Files to BodyLapse..."
3. Add `LanguageManager.swift`
4. Make sure target membership is checked for BodyLapse

### 4. Configure Localizable.strings Files

For each Localizable.strings file:
1. Select the file in Xcode
2. Open the File Inspector (right panel)
3. Under "Localization", make sure the appropriate language is checked

### 5. Update Info.plist (Optional)

To restrict the app to specific localizations:
1. Open Info.plist
2. Add key: `CFBundleLocalizations`
3. Set as Array with values:
   - `en`
   - `ja`
   - `ko`
   - `es`

## Features Implemented

### Automatic Language Detection
- The app automatically detects the device's language on first launch
- Falls back to English if the device language is not supported

### Manual Language Switching
- Users can change language from Settings → Photo Settings → Language
- The app refreshes immediately after language change
- Language preference is saved and persists across app launches

### Localized Content
All user-facing text has been localized including:
- Tab bar labels
- Navigation titles
- Button labels
- Alert messages
- Form fields and placeholders
- Error messages
- Settings and preferences
- Onboarding screens

## Testing Language Switching

1. **On Simulator/Device**:
   - Go to Settings → Photo Settings → Language
   - Select a different language
   - The app will refresh with the new language

2. **System Language**:
   - Change device language in iOS Settings → General → Language & Region
   - Launch the app - it should use the system language if supported

## Adding New Localizations

To add a new language:

1. Create a new `.lproj` folder (e.g., `fr.lproj` for French)
2. Copy an existing `Localizable.strings` file into it
3. Translate all the string values
4. Add the language code to `LanguageManager.supportedLanguages`
5. Add the language name to `LanguageManager.languageNames`
6. Follow the Xcode configuration steps above

## Common Issues and Solutions

### Strings Not Updating After Language Change
- Make sure all views use `.localized` extension
- Verify the string key exists in all Localizable.strings files
- Check that Bundle.setLanguage() is working correctly

### Language Not Appearing in Settings
- Verify the language is added to `supportedLanguages` in LanguageManager
- Check that the corresponding `.lproj` folder exists

### App Crashes on Language Switch
- Ensure all Localizable.strings files have the same keys
- Check for missing translations or syntax errors in .strings files

## Maintenance Notes

- When adding new UI text, always use localized strings
- Add the key to all Localizable.strings files
- Use descriptive key names following the pattern: `section.element`
- Keep translations consistent across the app
- Test all languages when making UI changes