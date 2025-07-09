# App Store Assets Compliance Report
Generated: 2025-07-08

## Current Status

### Screenshots
| Language | Resolution | Device Type | Count | File Size | Format |
|----------|------------|-------------|-------|-----------|---------|
| EN | 2688×1242 | 6.5" iPhone | 4 | 1.6-1.9M | PNG |
| JP | 2688×1242 | 6.5" iPhone | 4 | 1.6-1.9M | PNG |
| KO | 2688×1242 | 6.5" iPhone | 4 | 1.6-1.8M | PNG |
| ES | 2688×1242 | 6.5" iPhone | 4 | 1.7-1.9M | PNG |

### App Preview Videos
| Language | Resolution | FPS | Duration | Audio | File Size |
|----------|------------|-----|----------|-------|-----------|
| EN | 1920×886 | 30 | 14.9s | Stereo | 1.5M |
| KO | 1920×886 | 30 | 14.8s | Stereo | 1.5M |
| ES | 1920×886 | 30 | 15.0s | Stereo | 1.5M |

## ❌ Critical Issues

### 1. **Wrong Screenshot Size**
- **Current**: 2688×1242 (6.5" iPhone - deprecated)
- **Required**: 2796×1290 or 2868×1320 (6.9" iPhone 16 Pro Max)
- **Action**: Resize all screenshots to 6.9" dimensions

### 2. **PNG Format Issue**
- **Current**: PNG with alpha channel (transparency)
- **Required**: RGB without transparency, 72 DPI
- **Action**: Convert PNGs to remove alpha channel

### 3. **Missing Japanese Video**
- **Current**: No app preview video for JP
- **Action**: Create Japanese app preview video

## ✅ Compliant Aspects

### Screenshots
- ✅ File sizes under 8MB limit
- ✅ Less than 10 screenshots per language
- ✅ Landscape orientation supported

### App Preview Videos
- ✅ H.264 format
- ✅ 30fps frame rate
- ✅ 15-30 second duration
- ✅ Stereo audio included
- ✅ Under 500MB file size
- ✅ Resolution meets minimum requirement (1920×1080)

## 📋 Action Items

### High Priority
1. **Resize Screenshots**: Convert all 2688×1242 screenshots to 2796×1290 or 2868×1320
2. **Remove Alpha Channel**: Convert PNGs to RGB without transparency
3. **Create JP Video**: Generate Japanese app preview video

### Recommended
1. **Video Duration**: Consider extending videos to 15 seconds minimum (KO is 14.8s)
2. **Additional Sizes**: Consider creating screenshots for other device sizes (6.1", 4.7") if UI differs

## Commands to Fix Issues

### Resize Screenshots to 6.9" (2796×1290)
```bash
# For each language directory
for file in *.png; do
    sips -z 1290 2796 "$file" --out "resized_69inch_$file"
done
```

### Remove Alpha Channel
```bash
# Convert PNG to RGB without alpha
for file in *.png; do
    sips -s format png -s formatOptions default "$file" --out "rgb_$file"
done
```

### Create Japanese Video
```bash
cd jp
ffmpeg -stream_loop 4 -i slide1_1920x886.mov -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -r 30 -t 15 -c:v libx264 -crf 18 -c:a aac -b:a 128k -shortest slide1_appstore_15sec.mov
```

## Summary
The current assets are close to compliance but require critical updates:
- All screenshots must be resized to the new 6.9" requirement
- PNG format needs adjustment to remove transparency
- Japanese language needs an app preview video

Once these issues are resolved, all assets will meet Apple's 2025 App Store requirements.