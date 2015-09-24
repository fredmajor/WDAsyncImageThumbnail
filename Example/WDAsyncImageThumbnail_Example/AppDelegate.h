#import <Cocoa/Cocoa.h>
#import <WDAsyncImageThumbnail/WDAsyncImageThumbnail.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, WDAsyncImageThumbnailDelegate>

@property (weak) IBOutlet NSImageView *image;
@property (weak) IBOutlet NSTextField *selectionLabel;

- (IBAction)selectPath:(id)sender;
- (IBAction)load:(id)sender;
@end

