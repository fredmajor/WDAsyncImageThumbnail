# WDAsyncImageThumbnail
This tiny project is here to load thumbnails of a media files - image or video - on a bunch of background threads. Once a thumbnail is loaded, you receive a callback on the main thread. The code uses system APIs and should be very fast, though I don't have any numbers on the performance. I use [UTIs](https://developer.apple.com/library/ios/documentation/Miscellaneous/Reference/UTIRef/Articles/System-DeclaredUniformTypeIdentifiers.html) to check the media file type. 
I use **dispatch_groups** so you can easly wait for a bunch of load tasks until they all complete. You can set how many load operations you want to run together in parallel. (Now there is no convinient API for that, just change a constant value if you wish. Pull requests very welcome.) The code seems to be well synchronized and I have not found any memory leaks. There is a test class witch a bunch of test cases to make contributions easier.

## Usage

To run the example project, clone the repo, and run `pod install` from the Example directory first. The test project is called **WDAsyncImageThumbnail_Example**.
See the test class (WDAsyncImageThumbnailTest) to see how to use the code. NSCache instance is required. Summary below.

### Load an image
````objective-c
NSCache *myCache = [[NSCache alloc]init];
NSURL *pic1URL = [myBundle URLForResource:@"testPics/0.JPG" withExtension:nil];
WDAsyncImageThumbnail *image = [WDAsyncImageThumbnail imageWithImageCache:myCache imageURL:pic1URL];
[im1 loadImageWithCallbackBlock:^(CGImageRef aImageRef, NSError *aError){
	//handler here, e.g.
    NSImage *im = [[NSImage alloc]initWithCGImage:aImageRef size:NSZeroSize];
}];
```

### Load with optional cancellation
Loading a thumbnail is an expensive IO operation and in certain cases you might want to cancell a scheduled load before it starts. (Let's say the image was to be presented in a grid but it is already scrolled away and is not visible anymore). You can use **WDAsyncImageThumbnailDelegate** for that. See the provided example project for more details. (Actually there's no more details :) )

````objective-c
WDAsyncImageThumbnail *imageThumbnail = [WDAsyncImageThumbnail imageWithImageCache:cache imageURL:fileUrl];
imageThumbnail.delegate = self;
[imageThumbnail loadImageWithCallbackBlock:^(CGImageRef aImageRef, NSError *aError) {
	self.image.image = [[NSImage alloc]initWithCGImage:aImageRef size:NSZeroSize];
}];
    
    ---------
    
#pragma mark - WDAsyncImageThumbnailDelegate
- (BOOL)imageWillLoad:(WDAsyncImageThumbnail *)aImage{
    NSLog(@"Image will laod now. Return NO to stop the load and save your IO.");
    return NO;
}
```

### Wait for a bunch of load tasks untill all are completed
This sort of stuff sooner or later causes headaches in Objective-C. So I use dispatch_groups. See the test class for more details. In a nutshell:

````objective-c
dispatch_group_t dispatchGroup = dispatch_group_create();
[WDAsyncImageThumbnail setDispatchGroup:dispatchGroup];
WDAsyncImageThumbnail *im1 = [WDAsyncImageThumbnail imageWithImageCache:imageCache imageURL:pic1URL];
WDAsyncImageThumbnail *im2 = [WDAsyncImageThumbnail imageWithImageCache:imageCache imageURL:pic2URL];
WDAsyncImageThumbnail *im3 = [WDAsyncImageThumbnail imageWithImageCache:imageCache imageURL:pic3URL];
[im1 loadImageWithCallbackBlock:^(CGImageRef aImageRef, NSError *aError) { /*your handler*/ }];
[im2 loadImageWithCallbackBlock:^(CGImageRef aImageRef, NSError *aError) { /*your handler*/ }];
[im3 loadImageWithCallbackBlock:^(CGImageRef aImageRef, NSError *aError) { /*your handler*/ }];
    
dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^{
	NSLog(@"All tasks finished! This is called async after all images are loaded.");
});
```

or if you want to wait synchronously.. (also see the test class for more details)

````objective-c
//somewhere...
dispatch_group_t dispatchGroup = dispatch_group_create();

- (void)someMethod{
    [WDAsyncImageThumbnail setDispatchGroup:dispatchGroup];
    WDAsyncImageThumbnail *im1 = [WDAsyncImageThumbnail imageWithImageCache:imageCache imageURL:pic1URL];
    WDAsyncImageThumbnail *im2 = [WDAsyncImageThumbnail imageWithImageCache:imageCache imageURL:pic2URL];
    WDAsyncImageThumbnail *im3 = [WDAsyncImageThumbnail imageWithImageCache:imageCache imageURL:pic3URL];
    [im1 loadImageWithCallbackBlock:^(CGImageRef aImageRef, NSError *aError) { /*your handler*/ }];
	[im2 loadImageWithCallbackBlock:^(CGImageRef aImageRef, NSError *aError) { /*your handler*/ }];
	[im3 loadImageWithCallbackBlock:^(CGImageRef aImageRef, NSError *aError) { /*your handler*/ }];
    [self waitForGroup];
    NSLog(@"When you see this text, all loads are already finished.");
}
----
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
```

## Installation

WDAsyncImageThumbnail is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "WDAsyncImageThumbnail"
```

## Author

Fred, 
major.freddy {aaatttt} yahoo {doot} com

## License

WDAsyncImageThumbnail is available under the MIT license. See the LICENSE file for more info.
