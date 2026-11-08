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
 * Process contour detection from UIImage mask
 * @param image Original image for size reference
 * @param maskImage UIImage containing the mask
 * @return Array of CGPoint values wrapped in NSValue
 */
+ (NSArray<NSValue *> *)processContourFromImage:(UIImage *)image withMaskImage:(UIImage *)maskImage;

@end

NS_ASSUME_NONNULL_END