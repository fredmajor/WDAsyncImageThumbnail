#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <Expecta/Expecta.h>
#import "WDAsyncImageThumbnail.h"
#import "WDDataUtils.h"

#define WD_ASSERT_MT NSAssert([NSThread isMainThread], @"Has to be run from main thread.");

#pragma clang diagnostic push
#pragma ide diagnostic ignored "ResourceNotFoundInspection"

@interface WDAsyncImageThumbnailTest : XCTestCase <WDAsyncImageThumbnailDelegate>

- (void)WD_mockLongLoad:(NSTimeInterval)aLoadTime;

- (void)waitForGroup;
@end

@implementation WDAsyncImageThumbnailTest{
    NSURL *pic1URL;
    NSURL *pic2URL;
    NSURL *pic3URL;
    NSURL *pic4URL;
    NSURL *pic5URL;
    NSURL *pic6URL;
    NSArray *picURLs;
    NSCache *imageCache;
    BOOL continueLoad;
    BOOL delegateCalled;
    dispatch_group_t dispatchGroup;
    id dataUtilsMoc;
    NSTimeInterval loadSleepTime;
    int64_t imageLoadCallCount;
    int64_t videoLoadCallCount;
}

- (void)setUp{

    [super setUp];
    NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
    pic1URL = [thisBundle URLForResource:@"testPics/0.JPG" withExtension:nil];
    pic2URL = [thisBundle URLForResource:@"testPics/1.JPG" withExtension:nil];
    pic3URL = [thisBundle URLForResource:@"testPics/2.JPG" withExtension:nil];
    pic4URL = [thisBundle URLForResource:@"testPics/3.JPG" withExtension:nil];
    pic5URL = [thisBundle URLForResource:@"testPics/4.JPG" withExtension:nil];
    pic6URL = [thisBundle URLForResource:@"testPics/5.JPG" withExtension:nil];
    picURLs = @[pic1URL, pic2URL, pic3URL, pic4URL, pic5URL, pic6URL];
    imageCache = [[NSCache alloc] init];
    continueLoad = YES;
    delegateCalled = NO;
    dispatchGroup = dispatch_group_create();
    [WDAsyncImageThumbnail setDispatchGroup:dispatchGroup];
}

- (void)tearDown{

    [self waitForGroup];
    [imageCache removeAllObjects];
    [dataUtilsMoc stopMocking];
    imageLoadCallCount = 0;
    videoLoadCallCount = 0;
    [super tearDown];
}

- (void)WD_mockLongLoad:(NSTimeInterval)aLoadTime{

    loadSleepTime = aLoadTime;

    dataUtilsMoc = [OCMockObject mockForClass:[WDDataUtils class]];
    [[[[dataUtilsMoc stub]
            classMethod]
            andCall:@selector(fake_newThumbnailForImage:heigth:error:) onObject:self]
            newThumbnailForImage:[OCMArg any] heigth:wdCollectionThumbnailMaxSize error:[OCMArg anyObjectRef]];
    [[[[dataUtilsMoc stub]
            classMethod]
            andCall:@selector(fake_newThumbnailForVideo:error:) onObject:self]
            newThumbnailForVideo:[OCMArg any] error:[OCMArg anyObjectRef]];
}

- (CGImageRef)fake_newThumbnailForImage:(NSURL *)imagePath heigth:(int)h error:(NSError *__autoreleasing *)aError{

    OSMemoryBarrier();
    OSAtomicIncrement64(&imageLoadCallCount);
    [NSThread sleepForTimeInterval:loadSleepTime];
    CGImageRef imRef = (__bridge_retained CGImageRef) [[NSObject alloc] init];
    return imRef;
}

- (CGImageRef)fake_newThumbnailForVideo:(NSURL *)videoPath error:(NSError *__autoreleasing *)aError{

    OSMemoryBarrier();
    OSAtomicIncrement64(&videoLoadCallCount);
    [NSThread sleepForTimeInterval:loadSleepTime];
    CGImageRef imRef = (__bridge_retained CGImageRef) [[NSObject alloc] init];
    return imRef;
}

#pragma mark - TEST

- (void)testItIgnoresSubsequentLoadOrders{
    //given
    [self WD_mockLongLoad:0.1];
    [WDAsyncImageThumbnail setDispatchGroup:dispatchGroup];
    WDAsyncImageThumbnail *image = [WDAsyncImageThumbnail imageWithImageCache:imageCache imageURL:pic1URL];

    //when
    [image loadImageWithCallbackBlock:^(CGImageRef aImageRef, NSError *aError){}];
    [image loadImageWithCallbackBlock:^(CGImageRef aImageRef, NSError *aError){}];
    [image loadImageWithCallbackBlock:^(CGImageRef aImageRef, NSError *aError){}];

    //test
    [self waitForGroup];
    OSMemoryBarrier();
    XCTAssertEqual(imageLoadCallCount, 1);
}

- (void)testItAsksIfIsVisibleJustBeforeLoad{

    [self WD_mockLongLoad:0.01];
    __block BOOL calledBack = NO;
    WDAsyncImageThumbnail *image = [WDAsyncImageThumbnail imageWithImageCache:imageCache imageURL:pic1URL];
    continueLoad = YES;
    image.delegate = self;
    [image loadImageWithCallbackBlock:^(CGImageRef aImageRef, NSError *aError){
        calledBack = YES;
    }];
    expect(delegateCalled && !calledBack).will.equal(YES);
}

- (void)testItsLoadCanBeCancelled{

    [self WD_mockLongLoad:0.1];
    WDAsyncImageThumbnail *im1 = [WDAsyncImageThumbnail imageWithImageCache:imageCache imageURL:pic1URL];
    WDAsyncImageThumbnail *im2 = [WDAsyncImageThumbnail imageWithImageCache:imageCache imageURL:pic2URL];
    WDAsyncImageThumbnail *im3 = [WDAsyncImageThumbnail imageWithImageCache:imageCache imageURL:pic3URL];
    WDAsyncImageThumbnail *im4 = [WDAsyncImageThumbnail imageWithImageCache:imageCache imageURL:pic4URL];

    __block NSUInteger callbackCount = 0;
    [im1 loadImageWithCallbackBlock:^(CGImageRef aImageRef, NSError *aError){
        callbackCount++;
    }];
    [im2 loadImageWithCallbackBlock:^(CGImageRef aImageRef, NSError *aError){
        callbackCount++;
    }];
    [im3 loadImageWithCallbackBlock:^(CGImageRef aImageRef, NSError *aError){
        callbackCount++;
    }];
    [im4 loadImageWithCallbackBlock:^(CGImageRef aImageRef, NSError *aError){
        callbackCount++;
    }];

    [im1 cancelLoad];
    [im2 cancelLoad];
    [im3 cancelLoad];
    [im4 cancelLoad];

    [self waitForGroup];
    XCTAssertLessThan(callbackCount, 4);
}

- (void)testItCallsBackOnMainThreadWhenImageIsLoaded{

    WDAsyncImageThumbnail *im1 = [WDAsyncImageThumbnail imageWithImageCache:imageCache imageURL:pic1URL];
    [im1 loadImageWithCallbackBlock:^(CGImageRef aImageRef, NSError *aError){
        WD_ASSERT_MT;
    }];
}

- (void)testItCachesImagesAndReadsFromCacheIfAvailable{

    //two pics referring to the same url
    [self WD_mockLongLoad:0.001];
    WDAsyncImageThumbnail *im1 = [WDAsyncImageThumbnail imageWithImageCache:imageCache imageURL:pic1URL];
    WDAsyncImageThumbnail *im2 = [WDAsyncImageThumbnail imageWithImageCache:imageCache imageURL:pic1URL];

    __block BOOL firstLoaded;
    [im1 loadImageWithCallbackBlock:^(CGImageRef aImageRef, NSError *aError){
        XCTAssertTrue(aImageRef != NULL);
        firstLoaded = YES;
    }];

    expect(firstLoaded).will.equal(YES);
    NSLog(@"first pic loaded");

    __block BOOL secondLoaded;
    [im2 loadImageWithCallbackBlock:^(CGImageRef aImageRef, NSError *aError){
        XCTAssertTrue(aImageRef != NULL);
        secondLoaded = YES;
    }];
    expect(secondLoaded).will.equal(YES);
    NSLog(@"second pic loaded.");

    //test
    XCTAssertEqual(imageLoadCallCount, 1);
}

- (void)testImageCanBeReleased{

    WDAsyncImageThumbnail *im1 = [WDAsyncImageThumbnail imageWithImageCache:imageCache imageURL:pic1URL];
    __block CGImageRef imRef;
    [im1 loadImageWithCallbackBlock:^(CGImageRef aImageRef, NSError *aError){
        imRef = aImageRef;
    }];
    [self waitForGroup];
    NSInteger retainBefore = CFGetRetainCount(imRef);
    XCTAssertEqual(retainBefore, 2);
    [im1 releaseImage];
    NSInteger retainAfter = CFGetRetainCount(imRef);
    XCTAssertEqual(retainAfter, 1);
}

- (void)testItLoadsAnImage{

    //given
    WDAsyncImageThumbnail *image = [WDAsyncImageThumbnail imageWithImageCache:imageCache imageURL:pic1URL];
    image.delegate = self;
    continueLoad = YES;
    XCTestExpectation *expectation;
    expectation = [self expectationWithDescription:@"image loaded callback"];

    //test
    [image loadImageWithCallbackBlock:^(CGImageRef aImageRef, NSError *aError){
        XCTAssertNil(aError);
        XCTAssertTrue(aImageRef);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
    NSLog(@"image loaded");
}

- (void)testParallelLoadIsOk{

    [WDAsyncImageThumbnail setDispatchGroup:dispatchGroup];
    __block NSUInteger finishedBlocks = 0;
    for(NSUInteger i = 0; i < picURLs.count; ++i){

        WDAsyncImageThumbnail *image = [WDAsyncImageThumbnail imageWithImageCache:imageCache imageURL:picURLs[i]];
        image.delegate = self;
        [image loadImageWithCallbackBlock:^(CGImageRef aImageRef, NSError *aError){
            XCTAssertNil(aError);
            XCTAssertTrue(aImageRef);
            finishedBlocks++;
        }];
    }
    [self waitForGroup];
    NSLog(@"all loads finished");
    XCTAssertEqual(finishedBlocks, picURLs.count);
}

#pragma mark - Image delegate

- (BOOL)imageWillLoad:(WDAsyncImageThumbnail *)aImage{

    delegateCalled = YES;
    return continueLoad;
}

#pragma mark - Helpers

- (void)waitForGroup{

    __block BOOL didComplete = NO;
    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^{
        didComplete = YES;
    });
    while( !didComplete ){
        NSTimeInterval const interval = 0.002;
        if( ![[NSRunLoop currentRunLoop]
                runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:interval]] ){
            [NSThread sleepForTimeInterval:interval];
        }
    }
}

@end

#pragma clang diagnostic pop
