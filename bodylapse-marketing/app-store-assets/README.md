# App Store Assets

This directory contains the resized assets for App Store submission.

## Resized Files (2688 × 1242px)

### PNG Images ✅
- `slide2_2688x1242.png` - Face Blur Privacy feature
- `slide3_2688x1242.png` - Weight & Body Fat Tracking
- `slide4_2688x1242.png` - Before/After Comparison
- `slide5_2688x1242.png` - Body Outline Detection

### Video File ⚠️
- `slide1_original.mov` - Original video (1680 × 770px)
  
**Note**: The video file needs to be resized to 2688 × 1242px using video editing software such as:
- Final Cut Pro
- Adobe Premiere Pro
- DaVinci Resolve
- iMovie
- QuickTime Player (Export with custom dimensions)

## How to resize the video

### Using QuickTime Player:
1. Open `slide1_original.mov` in QuickTime Player
2. File > Export As > 1080p (or higher)
3. In the export dialog, click "Options"
4. Set custom size to 2688 × 1242
5. Export the video

### Using command line (requires ffmpeg):
```bash
ffmpeg -i slide1_original.mov -vf "scale=2688:1242:force_original_aspect_ratio=decrease,pad=2688:1242:(ow-iw)/2:(oh-ih)/2" -c:v libx264 -crf 18 slide1_2688x1242.mov
```

## Submission Guidelines

All App Store preview videos and screenshots must be exactly 2688 × 1242 pixels for 5.5" display (iPhone 8 Plus, 7 Plus, 6s Plus).