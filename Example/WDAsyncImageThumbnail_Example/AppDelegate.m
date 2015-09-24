#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate{
    NSCache * cache;
    NSURL *fileUrl;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc]init];
    });
}

- (IBAction)selectPath:(id)sender {
    NSOpenPanel *openDlg = [NSOpenPanel openPanel];
    [openDlg setCanChooseFiles:YES];
    [openDlg setCanChooseDirectories:NO];
    [openDlg setAllowsMultipleSelection:NO];
    
    [openDlg beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        fileUrl = [openDlg URL];
        self.selectionLabel.stringValue = [fileUrl absoluteString];
    }];
}

- (IBAction)load:(id)sender {
    WDAsyncImageThumbnail *imageThumbnail = [WDAsyncImageThumbnail imageWithImageCache:cache imageURL:fileUrl];
    imageThumbnail.delegate = self;
    [imageThumbnail loadImageWithCallbackBlock:^(CGImageRef aImageRef, NSError *aError) {
        self.image.image = [[NSImage alloc]initWithCGImage:aImageRef size:NSZeroSize];
    }];
}

#pragma mark - WDAsyncImageThumbnailDelegate
- (BOOL)imageWillLoad:(WDAsyncImageThumbnail *)aImage{
    NSLog(@"Image will laod now. Return NO to stop the load.");
    return YES;
}

@end
