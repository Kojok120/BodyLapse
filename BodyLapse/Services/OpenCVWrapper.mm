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

@end