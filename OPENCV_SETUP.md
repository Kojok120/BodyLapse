# OpenCV Setup Instructions for BodyLapse

## Completed Steps

1. **Downloaded OpenCV 4.11.0 prebuilt iOS framework**
2. **Created Framework structure**:
   - `Frameworks/opencv2.framework` - OpenCV framework
3. **Created Bridging Header**:
   - `BodyLapse/BodyLapse-Bridging-Header.h`
4. **Created OpenCV Wrapper**:
   - `BodyLapse/Services/OpenCVWrapper.h`
   - `BodyLapse/Services/OpenCVWrapper.mm`
5. **Updated BodyContourService.swift** to use OpenCV

## Manual Xcode Configuration Required

### 1. Add OpenCV Framework to Project
1. Open `BodyLapse.xcodeproj` in Xcode
2. Select the BodyLapse target
3. Go to "General" tab → "Frameworks, Libraries, and Embedded Content"
4. Click "+" and add `Frameworks/opencv2.framework`
5. Set to "Embed & Sign"

### 2. Configure Bridging Header
1. Select the BodyLapse target
2. Go to "Build Settings" tab
3. Search for "Objective-C Bridging Header"
4. Set the path to: `BodyLapse/BodyLapse-Bridging-Header.h`

### 3. Add OpenCV Files to Project
1. Right-click on the Services folder in Xcode
2. Select "Add Files to BodyLapse..."
3. Add:
   - `OpenCVWrapper.h`
   - `OpenCVWrapper.mm`
4. Make sure "Copy items if needed" is unchecked (files are already in place)
5. Ensure target membership is checked for BodyLapse

### 4. Configure C++ Settings
1. Select the BodyLapse target
2. Go to "Build Settings" tab
3. Search for "C++ Standard Library"
4. Set to "libc++ (LLVM C++ standard library)"
5. Search for "Enable Modules"
6. Set to "Yes"

### 5. Update Framework Search Paths
1. In Build Settings, search for "Framework Search Paths"
2. Add: `$(PROJECT_DIR)/Frameworks`

## Testing the Integration

After completing the manual configuration:
1. Build the project (Cmd+B)
2. Run on a device or simulator
3. Test the onboarding flow with contour detection

## Improvements Made with OpenCV

1. **Better edge detection** using Canny edge detection
2. **Smoother contours** with morphological operations
3. **More accurate body outline** using findContours
4. **Gaussian smoothing** for cleaner results
5. **Douglas-Peucker algorithm** for optimal point reduction

## Troubleshooting

If you encounter build errors:
1. Make sure all files are added to the project
2. Verify the bridging header path is correct
3. Check that opencv2.framework is properly embedded
4. Clean build folder (Shift+Cmd+K) and rebuild