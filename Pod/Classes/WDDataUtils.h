#import <Cocoa/Cocoa.h>

#define WD_ASYNC_IMAGE_ERROR_DOMAIN @"WD_ASYNC_IMAGE_ERROR_DOMAIN"

@interface WDDataUtils : NSObject{}

#pragma mark - UTIs

+ (BOOL)isFilePhoto:(NSURL *)aUrl;

+ (BOOL)doesUti:(CFStringRef)aUti conformToUtiType:(CFStringRef)aUtiType;

+ (BOOL)isFileVideo:(NSURL *)url;

#pragma mark - Images

+ (CGImageRef)newThumbnailForVideo:(NSURL *)videoPath error:(NSError *__autoreleasing *)aError;

+ (CGImageRef)newThumbnailForImage:(NSURL *)imagePath heigth:(int)h error:(NSError *__autoreleasing *)aError;

@end
