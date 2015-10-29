#import "WDAsyncImageThumbnail.h"
#import "WDThumbnailDataUtils.h"

@interface WDAsyncImageThumbnail ()

- (void)WD_cacheImage:(CGImageRef)aImage self:(WDAsyncImageThumbnail *)aSelf;

- (CGImageRef)WD_getImageFromCacheSelf:(WDAsyncImageThumbnail *)aSelf;

- (void)WD_scheduleAsyncLoadWithCompletionBlock:(void (^)(CGImageRef aImageRef, NSError *aError))aBlock;

- (void)WD_runCallbackBlock:(void (^)(CGImageRef aImageRef, NSError *aError))aBlock
                 syncObject:(id)aSyncObj
                    picture:(CGImageRef)aPic
                      error:(NSError *)aErr;

- (BOOL)WD_handleLoadCancellation:(id)syncObj;
@end

@implementation WDAsyncImageThumbnail{
    BOOL isCancelled;
}

#pragma mark - Initialization and backend

+ (void)initialize{

    if( self == [WDAsyncImageThumbnail class] ){
        [[self class] setDispatchGroup:[[self class] defaultDispatchGroup]];
        [[self class] initDispatchSemaphore];
    }
}

static dispatch_group_t dispatchGroup;
static dispatch_semaphore_t loadSemaphore;

+ (void)initDispatchSemaphore{

    @synchronized(self){
        static dispatch_once_t dOnceTok;
        dispatch_once(&dOnceTok, ^{
            loadSemaphore = dispatch_semaphore_create(wdCollectionLoadingThreads);
        });
    }
}

+ (dispatch_semaphore_t)dispatchSemaphore{

    @synchronized(self){
        return loadSemaphore;
    }
}

+ (dispatch_group_t)defaultDispatchGroup{

    static dispatch_once_t dOnceToken;
    static dispatch_group_t defaultGroup;
    dispatch_once(&dOnceToken, ^{
        defaultGroup = dispatch_group_create();
    });

    return defaultGroup;
}

+ (void)setDispatchGroup:(dispatch_group_t)aDispatchGroup{

    @synchronized(self){
        dispatchGroup = aDispatchGroup;
    }
}

+ (dispatch_group_t)dispatchGroup{

    @synchronized(self){
        return dispatchGroup;
    }
}

- (instancetype)initWithImageCache:(NSCache *)imageCache imageURL:(NSURL *)imageURL{

    self = [super init];
    if( self ){
        _imageCache = imageCache;
        _imageURL = imageURL;
        _imageState = WD_TLI_IDLE;
        isCancelled = NO;
    }

    return self;
}

+ (instancetype)imageWithImageCache:(NSCache *)imageCache imageURL:(NSURL *)imageURL{

    return [[self alloc] initWithImageCache:imageCache imageURL:imageURL];
}

#pragma mark - Interface

- (void)cancelLoad{

    WDThreadLoadedImageState state;
    @synchronized(self){
        state = _imageState;
        isCancelled = YES;
    }
    NSLog(@"Image order to cancell. Image state during cancel was: %lu", state);
}

- (void)releaseImage{

    @synchronized(self){
        CGImageRef im;
        if( (im = [self WD_getImageFromCacheSelf:self]) ){
            [self.imageCache removeObjectForKey:[self.imageURL absoluteString]];
            CGImageRelease(im);
        }
    }
}

- (void)loadImageWithCallbackBlock:(void (^)(CGImageRef aImageRef, NSError *aError))aBlock{

    @synchronized(self){
        switch(_imageState){
            case WD_TLI_IDLE:{
                isCancelled = NO;
                CGImageRef pCGImage = [self WD_getImageFromCacheSelf:self];
                if( pCGImage ){
                    NSLog(@"Image already in cache. No need to load.url=%@"
                    , [self.imageURL lastPathComponent]);
                    _imageState = WD_TLI_LOAD_COMPLETED;
                    aBlock(pCGImage, nil);
                    return;
                }

                NSLog(@"scheduling a load.pic=%@", [self.imageURL lastPathComponent]);
                _imageState = WD_TLI_LOAD_SCHEDULED;
                [self WD_scheduleAsyncLoadWithCompletionBlock:aBlock];
                break;
            }
            case WD_TLI_LOAD_COMPLETED:{
                NSLog(@"Load complete. Getting image from cache and calling back.");
                CGImageRef pImage = [self WD_getImageFromCacheSelf:self];
                aBlock(pImage, nil);
                break;
            }
            case WD_TLI_LOAD_SCHEDULED:{
                NSLog(@"Load is already scheduled. Leaving.");
                break;
            }
            default:{
                NSLog(@"Unknown state. Will raise an exception.");
                [NSException raise:@"unknown state" format:@"unknown state"];
            }
        }
    }
}

#pragma mark - Private methods

- (void)WD_cacheImage:(CGImageRef)aImage self:(WDAsyncImageThumbnail *)aSelf{

//    [aSelf.imageCache setObject:CFBridgingRelease(aImage) forKey:[aSelf.imageURL absoluteString]];
    [aSelf.imageCache setObject:(__bridge id) aImage forKey:[aSelf.imageURL absoluteString]];
}

- (CGImageRef)WD_getImageFromCacheSelf:(WDAsyncImageThumbnail *)aSelf{

    return (__bridge CGImageRef) [aSelf.imageCache objectForKey:[aSelf.imageURL absoluteString]];
}

static int64_t testC = 0;

- (void)WD_scheduleAsyncLoadWithCompletionBlock:(void (^)(CGImageRef aImageRef, NSError *aError))aBlock{

    __weak WDAsyncImageThumbnail *weakSelf = self;
    dispatch_group_async([[self class] dispatchGroup], dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)
            , ^{

                if( !weakSelf ){
                    NSLog(@"Seems that the photo object has been deallocated before load started. Leaving..");
                    //fuck the status, object already dead
                    return;
                }

                WDAsyncImageThumbnail *strongSelf = weakSelf;
                if( [strongSelf WD_handleLoadCancellation:strongSelf] ){return;}

                @synchronized(strongSelf){
                    __block BOOL continueLoad = YES;
                    if( strongSelf.delegate
                        && [strongSelf.delegate respondsToSelector:@selector(imageWillLoad:)] ){
                        dispatch_sync(dispatch_get_main_queue(), ^{
                            continueLoad = [strongSelf.delegate imageWillLoad:strongSelf];
                        });
                    }
                    if( !continueLoad ){
                        NSLog(@"delagate said to stop the load. Cancelling..");
                        isCancelled = YES;
                        if( [strongSelf WD_handleLoadCancellation:strongSelf] ){return;}
                    }
                }

                CGImageRef pic = NULL;
                NSError *error;
                dispatch_semaphore_t dSema = [[strongSelf class] dispatchSemaphore];
                dispatch_semaphore_wait(dSema, DISPATCH_TIME_FOREVER);
                OSAtomicIncrement64Barrier(&testC);
                NSLog(@"load counter start=%lld", testC);
                @try{
                    if( [strongSelf WD_handleLoadCancellation:strongSelf] ){return;}

                    NSLog(@"actual load will start for pic=%@", [strongSelf.imageURL lastPathComponent]);
                    if( [WDThumbnailDataUtils isFilePhoto:strongSelf.imageURL] ){
                        NSError *imageLoadErr;
                        pic = [WDThumbnailDataUtils newThumbnailForImage:strongSelf.imageURL
                                           heigth:wdCollectionThumbnailMaxSize
                                           error:&imageLoadErr];
                        if( imageLoadErr ) error = imageLoadErr;
                    }else if( [WDThumbnailDataUtils isFileVideo:strongSelf.imageURL] ){
                        NSError *videoLoadErr;
                        pic = [WDThumbnailDataUtils newThumbnailForVideo:strongSelf.imageURL error:&videoLoadErr];
                        if( videoLoadErr ) error = videoLoadErr;
                    }else{
                        NSLog(@"File neither photo nor video. File url=%@", strongSelf.imageURL);
                        error = [NSError errorWithDomain:WD_ASYNC_IMAGE_ERROR_DOMAIN code:-1 userInfo:nil];
                    }
                }@finally{
                    dispatch_semaphore_signal(dSema);
                    NSLog(@"actual load did finish for pic=%@", [strongSelf.imageURL lastPathComponent]);
                    OSAtomicDecrement64Barrier(&testC);
                    NSLog(@"load counter finish=%lld", testC);
                }

                if( !pic && !error ){
                    NSAssert(NO, @"Fucked up!");
                }

                if( pic ){
                    [strongSelf WD_cacheImage:pic self:strongSelf];
                    NSLog(@"Image cached");
                }

                if( [strongSelf WD_handleLoadCancellation:strongSelf] ){return;}
                _imageState = WD_TLI_LOAD_COMPLETED;

                [strongSelf WD_runCallbackBlock:aBlock syncObject:strongSelf picture:pic error:error];
            });
}

- (void)WD_runCallbackBlock:(void (^)(CGImageRef aImageRef, NSError *aError))aBlock
                 syncObject:(id)aSyncObj
                    picture:(CGImageRef)aPic
                      error:(NSError *)aErr{

    @synchronized(aSyncObj){
        if( [NSThread isMainThread] ){
            aBlock(aPic, aErr);
        }else{
            dispatch_async(dispatch_get_main_queue(), ^{
                @synchronized(aSyncObj){
                    if( !isCancelled ){
                        aBlock(aPic, aErr);
                    }else{
                        NSLog(@"Image load cancelled when block was waiting to run actual callback.Url=%@"
                        , [((WDAsyncImageThumbnail *) aSyncObj).imageURL lastPathComponent]);
                    }
                }
            });
        }
    }
}

- (BOOL)WD_handleLoadCancellation:(id)syncObj{

    @synchronized(syncObj){
        BOOL initIsCancelled = isCancelled;
        if( isCancelled ){
            NSLog(@"image load cancelled.Url=%@"
            , [((WDAsyncImageThumbnail *) syncObj).imageURL lastPathComponent]);
            isCancelled = NO;
            _imageState = WD_TLI_IDLE;
        }
        return initIsCancelled;
    }
}

- (void)dealloc{

    NSLog(@"deallocating image: %@", [self.imageURL lastPathComponent]);
}

@end