//
//  OpenCVWrapper.mm
//  BodyLapse
//
//  OpenCV wrapper implementation
//

#import "OpenCVWrapper.h"

// Include OpenCV headers before any Objective-C headers to avoid macro conflicts
#ifdef __cplusplus
#undef NO
#import <opencv2/core.hpp>
#import <opencv2/imgproc.hpp>
#import <opencv2/imgcodecs.hpp>
#import <opencv2/imgcodecs/ios.h>
#define NO (BOOL)0
#endif

using namespace std;

@implementation OpenCVWrapper

+ (NSArray<NSValue *> *)extractContourFromMask:(UIImage *)maskImage {
    // Convert UIImage to cv::Mat
    cv::Mat cvMask;
    UIImageToMat(maskImage, cvMask);
    
    // Convert to grayscale if needed
    if (cvMask.channels() > 1) {
        cv::cvtColor(cvMask, cvMask, cv::COLOR_RGBA2GRAY);
    }
    
    // Apply threshold to ensure binary mask
    cv::Mat binaryMask;
    cv::threshold(cvMask, binaryMask, 127, 255, cv::THRESH_BINARY);
    
    // Find contours
    vector<vector<cv::Point>> contours;
    vector<cv::Vec4i> hierarchy;
    cv::findContours(binaryMask, contours, hierarchy, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
    
    // Find the largest contour (assuming it's the person)
    if (contours.empty()) {
        return @[];
    }
    
    size_t largestIdx = 0;
    double largestArea = 0;
    for (size_t i = 0; i < contours.size(); i++) {
        double area = cv::contourArea(contours[i]);
        if (area > largestArea) {
            largestArea = area;
            largestIdx = i;
        }
    }
    
    // Convert contour points to NSArray
    NSMutableArray<NSValue *> *points = [NSMutableArray array];
    
    // Apply smoothing using approxPolyDP
    vector<cv::Point> smoothedContour;
    double epsilon = 0.001 * cv::arcLength(contours[largestIdx], true);
    cv::approxPolyDP(contours[largestIdx], smoothedContour, epsilon, true);
    
    // Scale points to original image size
    CGFloat scaleX = maskImage.size.width / cvMask.cols;
    CGFloat scaleY = maskImage.size.height / cvMask.rows;
    
    for (const auto& point : smoothedContour) {
        CGPoint cgPoint = CGPointMake(point.x * scaleX, point.y * scaleY);
        [points addObject:[NSValue valueWithCGPoint:cgPoint]];
    }
    
    return points;
}

+ (NSArray<NSValue *> *)processContourFromPixelBuffer:(UIImage *)image withMask:(CVPixelBufferRef)maskBuffer {
    // Lock the pixel buffer
    CVPixelBufferLockBaseAddress(maskBuffer, kCVPixelBufferLock_ReadOnly);
    
    // Get buffer properties
    size_t width = CVPixelBufferGetWidth(maskBuffer);
    size_t height = CVPixelBufferGetHeight(maskBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(maskBuffer);
    void *baseAddress = CVPixelBufferGetBaseAddress(maskBuffer);
    
    // Check pixel format
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(maskBuffer);
    NSLog(@"OpenCV: Pixel format: %u, width: %zu, height: %zu", (unsigned int)pixelFormat, width, height);
    NSLog(@"OpenCV: Image orientation: %ld", (long)image.imageOrientation);
    
    cv::Mat cvMask;
    
    // Create mask based on pixel format
    if (pixelFormat == kCVPixelFormatType_OneComponent8) {
        // 8-bit grayscale - need to clone to avoid issues with stride
        cv::Mat tempMask = cv::Mat((int)height, (int)width, CV_8UC1, baseAddress, bytesPerRow);
        cvMask = tempMask.clone();
    } else if (pixelFormat == kCVPixelFormatType_DepthFloat32) {
        // 32-bit float - Vision framework outputs 0.0 (background) to 1.0 (foreground)
        // Note: bytesPerRow includes padding, so we need to handle stride correctly
        size_t floatBytesPerRow = bytesPerRow / sizeof(float) * sizeof(float);
        cv::Mat floatMask = cv::Mat((int)height, (int)width, CV_32F, baseAddress, floatBytesPerRow);
        
        // Debug: Check float values
        double minFloat, maxFloat;
        cv::minMaxLoc(floatMask, &minFloat, &maxFloat);
        NSLog(@"OpenCV: Float mask range: %.6f - %.6f", minFloat, maxFloat);
        
        // Convert float [0.0-1.0] to 8-bit [0-255]
        cv::Mat scaledMask;
        floatMask.convertTo(scaledMask, CV_8U, 255.0);
        cvMask = scaledMask.clone();
    } else {
        // Try to handle as 8-bit
        cv::Mat tempMask = cv::Mat((int)height, (int)width, CV_8UC1, baseAddress, bytesPerRow);
        cvMask = tempMask.clone();
    }
    
    // Debug: Check mask values
    double minVal, maxVal;
    cv::minMaxLoc(cvMask, &minVal, &maxVal);
    NSLog(@"OpenCV: Mask value range: %.2f - %.2f", minVal, maxVal);
    
    // Count non-zero pixels
    int nonZeroCount = cv::countNonZero(cvMask);
    NSLog(@"OpenCV: Non-zero pixels: %d / %d", nonZeroCount, (int)(width * height));
    
    // Apply threshold - for float masks converted to 8-bit, use a reasonable threshold
    cv::Mat binaryMask;
    double thresholdValue = 128; // Middle value for converted float masks
    cv::threshold(cvMask, binaryMask, thresholdValue, 255, cv::THRESH_BINARY);
    
    // Count pixels after threshold
    int nonZeroAfterThreshold = cv::countNonZero(binaryMask);
    NSLog(@"OpenCV: Non-zero pixels after threshold: %d", nonZeroAfterThreshold);
    
    // Debug: Save binary mask as a simple image
    // Create UIImage from cv::Mat
    UIImage *debugImage = nil;
    @autoreleasepool {
        // Convert to RGBA for UIImage
        cv::Mat rgbaMask;
        cv::cvtColor(binaryMask, rgbaMask, cv::COLOR_GRAY2RGBA);
        
        // Create UIImage
        NSData *data = [NSData dataWithBytes:rgbaMask.data length:rgbaMask.elemSize() * rgbaMask.total()];
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
        
        CGImageRef imageRef = CGImageCreate(rgbaMask.cols,
                                           rgbaMask.rows,
                                           8,
                                           8 * rgbaMask.channels(),
                                           rgbaMask.step[0],
                                           colorSpace,
                                           kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault,
                                           provider,
                                           NULL,
                                           false,
                                           kCGRenderingIntentDefault);
        
        debugImage = [[UIImage alloc] initWithCGImage:imageRef];
        
        CGImageRelease(imageRef);
        CGDataProviderRelease(provider);
        CGColorSpaceRelease(colorSpace);
        
        if (debugImage) {
            NSData *pngData = UIImagePNGRepresentation(debugImage);
            
            // Save to Documents directory for easier access
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentsDirectory = [paths firstObject];
            NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"opencv_binary_mask.png"];
            
            [pngData writeToFile:filePath atomically:YES];
            NSLog(@"OpenCV: Binary mask saved to Documents: %@", filePath);
            
            // Also save to tmp for backward compatibility
            NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"opencv_binary_mask.png"];
            [pngData writeToFile:tempPath atomically:YES];
        }
    }
    
    // Skip morphological operations since Vision mask is already clean
    
    // Find contours
    vector<vector<cv::Point>> contours;
    vector<cv::Vec4i> hierarchy;
    cv::findContours(binaryMask, contours, hierarchy, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
    
    NSLog(@"OpenCV: Found %zu contours", contours.size());
    
    // Unlock pixel buffer
    CVPixelBufferUnlockBaseAddress(maskBuffer, kCVPixelBufferLock_ReadOnly);
    
    if (contours.empty()) {
        NSLog(@"OpenCV: No contours found");
        return @[];
    }
    
    // Find the largest contour
    size_t largestIdx = 0;
    double largestArea = 0;
    for (size_t i = 0; i < contours.size(); i++) {
        double area = cv::contourArea(contours[i]);
        NSLog(@"OpenCV: Contour %zu area: %.2f", i, area);
        if (area > largestArea) {
            largestArea = area;
            largestIdx = i;
        }
    }
    
    NSLog(@"OpenCV: Selected contour %zu with area %.2f", largestIdx, largestArea);
    NSLog(@"OpenCV: Contour has %zu points", contours[largestIdx].size());
    
    // Get bounding box of the largest contour
    cv::Rect boundingBox = cv::boundingRect(contours[largestIdx]);
    NSLog(@"OpenCV: Bounding box - x:%d, y:%d, width:%d, height:%d", 
          boundingBox.x, boundingBox.y, boundingBox.width, boundingBox.height);
    NSLog(@"OpenCV: Bounding box center: (%.0f, %.0f)", 
          boundingBox.x + boundingBox.width/2.0, boundingBox.y + boundingBox.height/2.0);
    
    // Use the contour directly without excessive smoothing
    vector<cv::Point> selectedContour = contours[largestIdx];
    
    // Apply minimal smoothing
    if (selectedContour.size() > 100) {
        double epsilon = 0.0005 * cv::arcLength(selectedContour, true);
        cv::approxPolyDP(selectedContour, selectedContour, epsilon, true);
        NSLog(@"OpenCV: After smoothing: %zu points", selectedContour.size());
    }
    
    // Convert to NSArray with proper scaling
    NSMutableArray<NSValue *> *points = [NSMutableArray array];
    
    // Handle image orientation
    // The mask is always in the original image coordinate system (landscape for iPhone photos)
    // But UIImage may be rotated for display
    BOOL needsRotation = (image.imageOrientation == UIImageOrientationRight || 
                         image.imageOrientation == UIImageOrientationLeft ||
                         image.imageOrientation == UIImageOrientationRightMirrored ||
                         image.imageOrientation == UIImageOrientationLeftMirrored);
    
    // Get the actual dimensions considering orientation
    CGFloat displayWidth = image.size.width;
    CGFloat displayHeight = image.size.height;
    
    // Mask dimensions match the CGImage dimensions (original photo dimensions)
    // For portrait photos taken with iPhone, the CGImage is actually landscape (4032x3024)
    // but UIImage displays it as portrait (3024x4032) due to orientation
    
    NSLog(@"OpenCV: Display size: %.0fx%.0f", displayWidth, displayHeight);
    NSLog(@"OpenCV: Mask size: %zux%zu", width, height);
    NSLog(@"OpenCV: Needs rotation: %@", needsRotation ? @"YES" : @"NO");
    
    // Sample points if there are too many
    int step = 1;
    if (selectedContour.size() > 360) {
        step = (int)(selectedContour.size() / 360);
    }
    
    for (size_t i = 0; i < selectedContour.size(); i += step) {
        const cv::Point& point = selectedContour[i];
        
        CGFloat x, y;
        
        if (needsRotation) {
            // The mask coordinates are in landscape orientation (4032x3024)
            // We need to rotate them to match the portrait display (3024x4032)
            // For UIImageOrientationRight: 
            // mask(x,y) -> display(height-y, x)
            if (image.imageOrientation == UIImageOrientationRight) {
                x = (height - point.y) * displayWidth / height;
                y = point.x * displayHeight / width;
            } else if (image.imageOrientation == UIImageOrientationLeft) {
                x = point.y * displayWidth / height;
                y = (width - point.x) * displayHeight / width;
            } else {
                // Default case, should not happen for iPhone photos
                x = point.x * displayWidth / width;
                y = point.y * displayHeight / height;
            }
        } else {
            // No rotation needed, direct mapping
            x = point.x * displayWidth / width;
            y = point.y * displayHeight / height;
        }
        
        // Ensure points are within bounds
        x = MAX(0, MIN(x, displayWidth - 1));
        y = MAX(0, MIN(y, displayHeight - 1));
        
        CGPoint cgPoint = CGPointMake(x, y);
        [points addObject:[NSValue valueWithCGPoint:cgPoint]];
    }
    
    // Debug: Print some sample points
    if (points.count > 0) {
        CGPoint first = [points[0] CGPointValue];
        CGPoint middle = [points[points.count/2] CGPointValue];
        CGPoint last = [points[points.count-1] CGPointValue];
        NSLog(@"OpenCV: Transformed points - First: (%.1f, %.1f), Middle: (%.1f, %.1f), Last: (%.1f, %.1f)", 
              first.x, first.y, middle.x, middle.y, last.x, last.y);
        
        // Also print original mask points for comparison
        if (selectedContour.size() > 0) {
            cv::Point firstMask = selectedContour[0];
            cv::Point middleMask = selectedContour[selectedContour.size()/2];
            cv::Point lastMask = selectedContour[selectedContour.size()-1];
            NSLog(@"OpenCV: Original mask points - First: (%d, %d), Middle: (%d, %d), Last: (%d, %d)",
                  firstMask.x, firstMask.y, middleMask.x, middleMask.y, lastMask.x, lastMask.y);
        }
    }
    
    NSLog(@"OpenCV: Returning %lu contour points", (unsigned long)points.count);
    
    return points;
}

+ (NSArray<NSValue *> *)processContourFromImage:(UIImage *)image withMaskImage:(UIImage *)maskImage {
    // Convert mask UIImage to cv::Mat
    cv::Mat cvMask;
    UIImageToMat(maskImage, cvMask);
    
    // Convert to grayscale if needed
    if (cvMask.channels() > 1) {
        cv::cvtColor(cvMask, cvMask, cv::COLOR_RGBA2GRAY);
    }
    
    // Debug: Check mask values
    double minVal, maxVal;
    cv::minMaxLoc(cvMask, &minVal, &maxVal);
    NSLog(@"OpenCV: Mask from UIImage - value range: %.2f - %.2f", minVal, maxVal);
    
    // Apply threshold
    cv::Mat binaryMask;
    double thresholdValue = 128; // Middle value
    cv::threshold(cvMask, binaryMask, thresholdValue, 255, cv::THRESH_BINARY);
    
    // Count non-zero pixels
    int nonZeroCount = cv::countNonZero(binaryMask);
    NSLog(@"OpenCV: Non-zero pixels after threshold: %d / %d", nonZeroCount, cvMask.rows * cvMask.cols);
    
    // Save binary mask for debugging
    @autoreleasepool {
        UIImage *debugImage = MatToUIImage(binaryMask);
        if (debugImage) {
            NSData *pngData = UIImagePNGRepresentation(debugImage);
            
            // Save to Documents directory
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentsDirectory = [paths firstObject];
            NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"opencv_binary_mask_from_uiimage.png"];
            
            [pngData writeToFile:filePath atomically:YES];
            NSLog(@"OpenCV: Binary mask saved to Documents: %@", filePath);
        }
    }
    
    // Find contours
    vector<vector<cv::Point>> contours;
    vector<cv::Vec4i> hierarchy;
    cv::findContours(binaryMask, contours, hierarchy, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
    
    NSLog(@"OpenCV: Found %zu contours", contours.size());
    
    if (contours.empty()) {
        return @[];
    }
    
    // Find the largest contour
    size_t largestIdx = 0;
    double largestArea = 0;
    for (size_t i = 0; i < contours.size(); i++) {
        double area = cv::contourArea(contours[i]);
        NSLog(@"OpenCV: Contour %zu area: %.2f", i, area);
        if (area > largestArea) {
            largestArea = area;
            largestIdx = i;
        }
    }
    
    NSLog(@"OpenCV: Selected contour %zu with area %.2f", largestIdx, largestArea);
    
    // Apply minimal smoothing
    vector<cv::Point> selectedContour = contours[largestIdx];
    if (selectedContour.size() > 100) {
        double epsilon = 0.001 * cv::arcLength(selectedContour, true);
        cv::approxPolyDP(selectedContour, selectedContour, epsilon, true);
    }
    
    // Convert to NSArray with proper scaling
    NSMutableArray<NSValue *> *points = [NSMutableArray array];
    
    // Handle orientation
    BOOL needsRotation = (image.imageOrientation == UIImageOrientationRight || 
                         image.imageOrientation == UIImageOrientationLeft);
    
    CGFloat displayWidth = image.size.width;
    CGFloat displayHeight = image.size.height;
    CGFloat maskWidth = cvMask.cols;
    CGFloat maskHeight = cvMask.rows;
    
    NSLog(@"OpenCV: Display size: %.0fx%.0f, Mask size: %.0fx%.0f", displayWidth, displayHeight, maskWidth, maskHeight);
    
    for (const auto& point : selectedContour) {
        CGFloat x, y;
        
        if (needsRotation && image.imageOrientation == UIImageOrientationRight) {
            // For UIImageOrientationRight: rotate 90 degrees clockwise
            x = (maskHeight - point.y) * displayWidth / maskHeight;
            y = point.x * displayHeight / maskWidth;
        } else {
            // No rotation needed
            x = point.x * displayWidth / maskWidth;
            y = point.y * displayHeight / maskHeight;
        }
        
        CGPoint cgPoint = CGPointMake(x, y);
        [points addObject:[NSValue valueWithCGPoint:cgPoint]];
    }
    
    NSLog(@"OpenCV: Returning %lu contour points", (unsigned long)points.count);
    return points;
}

+ (UIImage *)createContourDebugImage:(UIImage *)image withContour:(NSArray<NSValue *> *)contourPoints {
    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    
    // Draw original image
    [image drawAtPoint:CGPointZero];
    
    // Draw contour
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, [UIColor greenColor].CGColor);
    CGContextSetLineWidth(context, 3.0);
    
    if (contourPoints.count > 0) {
        CGPoint firstPoint = [contourPoints[0] CGPointValue];
        CGContextMoveToPoint(context, firstPoint.x, firstPoint.y);
        
        for (NSInteger i = 1; i < contourPoints.count; i++) {
            CGPoint point = [contourPoints[i] CGPointValue];
            CGContextAddLineToPoint(context, point.x, point.y);
        }
        
        // Close the path
        CGContextAddLineToPoint(context, firstPoint.x, firstPoint.y);
        CGContextStrokePath(context);
    }
    
    UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return resultImage ?: image;
}

@end