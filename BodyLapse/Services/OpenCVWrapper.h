//
//  OpenCVWrapper.h
//  BodyLapse
//
//  OpenCV wrapper for Swift integration
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

@interface OpenCVWrapper : NSObject

/**
 * Extract contour points from a binary mask image using OpenCV
 * @param maskImage Binary mask image (UIImage)
 * @return Array of CGPoint values wrapped in NSValue
 */
+ (NSArray<NSValue *> *)extractContourFromMask:(UIImage *)maskImage;

/**
 * Process contour detection from CVPixelBuffer mask
 * @param image Original image for size reference
 * @param maskBuffer CVPixelBuffer containing the mask
 * @return Array of CGPoint values wrapped in NSValue
 */
+ (NSArray<NSValue *> *)processContourFromPixelBuffer:(UIImage *)image withMask:(CVPixelBufferRef)maskBuffer;

/**
 * Process contour detection from UIImage mask
 * @param image Original image for size reference
 * @param maskImage UIImage containing the mask
 * @return Array of CGPoint values wrapped in NSValue
 */
+ (NSArray<NSValue *> *)processContourFromImage:(UIImage *)image withMaskImage:(UIImage *)maskImage;

/**
 * Create a debug image showing the detected contour
 * @param image Original image
 * @param contourPoints Array of contour points
 * @return Image with contour overlay
 */
+ (UIImage *)createContourDebugImage:(UIImage *)image withContour:(NSArray<NSValue *> *)contourPoints;

@end

NS_ASSUME_NONNULL_END