#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

//! Project version number for WDAsyncImageThumbnail.
FOUNDATION_EXPORT double WDAsyncImageThumbnailVersionNumber;

//! Project version string for WDAsyncImageThumbnail.
FOUNDATION_EXPORT const unsigned char WDAsyncImageThumbnailVersionString[];

#define wdCollectionLoadingThreads 3
#define wdCollectionThumbnailMaxSize 300

@class WDAsyncImageThumbnail;

@protocol WDAsyncImageThumbnailDelegate <NSObject>

@required
/**
 * Returning NO cancels the load.
 */
- (BOOL)imageWillLoad:(WDAsyncImageThumbnail *)aImage;
@end

@interface WDAsyncImageThumbnail : NSObject

	typedef NS_ENUM (NSUInteger, WDThreadLoadedImageState){
	WD_TLI_IDLE,
	WD_TLI_LOAD_SCHEDULED,
	WD_TLI_LOAD_COMPLETED
};

@property(readonly) NSCache *imageCache;
@property(readonly) NSURL *imageURL;
@property(readonly) WDThreadLoadedImageState imageState;
@property(nonatomic, weak) id <WDAsyncImageThumbnailDelegate> delegate;

#pragma mark - Main interface

- (void)loadImageWithCallbackBlock:(void (^)(CGImageRef aImageRef, NSError *aError))aBlock;

- (void)cancelLoad;

- (void)releaseImage;

#pragma mark - Backend

+ (dispatch_group_t)defaultDispatchGroup;

+ (void)setDispatchGroup:(dispatch_group_t)aDispatchGroup;

+ (dispatch_group_t)dispatchGroup;

- (instancetype)initWithImageCache:(NSCache *)imageCache imageURL:(NSURL *)imageURL;

+ (instancetype)imageWithImageCache:(NSCache *)imageCache imageURL:(NSURL *)imageURL;

@end