#import "WDDataUtils.h"
#import <AVFoundation/AVFoundation.h>

@interface WDDataUtils ()

#pragma mark - UTIs

+ (CFStringRef)getFileUTIType:(NSURL *)url;

+ (BOOL)isImageFileUTIBased:(CFStringRef)uti;

+ (BOOL)isVideoFileUTIBased:(CFStringRef)uti;

@end

@implementation WDDataUtils

#pragma mark UTI file types analysis

+ (CFStringRef)getFileUTIType:(NSURL *)url{

    return (__bridge CFStringRef) ([[NSWorkspace sharedWorkspace] typeOfFile:[url path] error:nil]);
}

+ (BOOL)isImageFileUTIBased:(CFStringRef)uti{

    return [self doesUti:uti conformToUtiType:kUTTypeImage];
}

+ (BOOL)doesUti:(CFStringRef)aUti conformToUtiType:(CFStringRef)aUtiType{

    if( aUti ){
        return UTTypeConformsTo(aUti, aUtiType);
    }else{
        return false;
    }
}

+ (BOOL)isVideoFileUTIBased:(CFStringRef)uti{

    return [self doesUti:uti conformToUtiType:kUTTypeMovie];
}

+ (BOOL)isFileVideo:(NSURL *)url{

    return [self isVideoFileUTIBased:[self getFileUTIType:url]];
}

+ (BOOL)isFilePhoto:(NSURL *)aUrl{

    return [self isImageFileUTIBased:[self getFileUTIType:aUrl]];
}

#pragma mark - Images

+ (CGImageRef)newThumbnailForVideo:(NSURL *)videoPath error:(NSError *__autoreleasing *)aError{

    CGImageRef videoThumbnail;
    [videoPath startAccessingSecurityScopedResource];
    AVAsset *vid = [AVAsset assetWithURL:videoPath];
    CMTime vDuration = vid.duration;
    CMTime thumbMoment = CMTimeMultiplyByFloat64(vDuration, 0.5f);
    AVAssetImageGenerator *imGen = [AVAssetImageGenerator assetImageGeneratorWithAsset:vid];
    videoThumbnail = [imGen copyCGImageAtTime:thumbMoment actualTime:NULL error:NULL];
    if( videoThumbnail == NULL ){
        NSLog(@"Unable to create video thumbnail");
        if( aError != NULL ){
            *aError = [NSError errorWithDomain:WD_ASYNC_IMAGE_ERROR_DOMAIN code:-42 userInfo:nil];
        }
        return NULL;
    }
    [videoPath stopAccessingSecurityScopedResource];
    return videoThumbnail;
}

+ (CGImageRef)newThumbnailForImage:(NSURL *)imagePath heigth:(int)h error:(NSError *__autoreleasing *)aError{

    CGImageSourceRef myImageSource;
    CFDictionaryRef myOptions = NULL;
    CFStringRef myKeys[2];
    CFTypeRef myValues[2];

    CGImageRef thumbnail = NULL;
    CFDictionaryRef myOptionsT = NULL;
    CFStringRef myKeysT[5];
    CFTypeRef myValuesT[5];
    CFNumberRef thumbnailSize;


    myKeys[0] = kCGImageSourceShouldCache;
    myValues[0] = (CFTypeRef) kCFBooleanTrue;
    myKeys[1] = kCGImageSourceShouldAllowFloat;
    myValues[1] = (CFTypeRef) kCFBooleanTrue;

    [imagePath startAccessingSecurityScopedResource];
    myOptions = CFDictionaryCreate(NULL, (const void **) myKeys, (const void **) myValues, 2
            , &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    myImageSource = CGImageSourceCreateWithURL((__bridge CFURLRef) imagePath, myOptions);
    CFRelease(myOptions);

    if( myImageSource == NULL ){
        NSLog(@"Image source is NULL.");
        if( aError != NULL ) *aError = [NSError errorWithDomain:WD_ASYNC_IMAGE_ERROR_DOMAIN code:-40 userInfo:nil];
        return NULL;
    }

    thumbnailSize = CFNumberCreate(NULL, kCFNumberIntType, &h);
    // Set up the thumbnail options.
    myKeysT[0] = kCGImageSourceCreateThumbnailWithTransform;
    myValuesT[0] = (CFTypeRef) kCFBooleanFalse;
    myKeysT[1] = kCGImageSourceCreateThumbnailFromImageIfAbsent;
    myValuesT[1] = (CFTypeRef) kCFBooleanTrue;
    myKeysT[2] = kCGImageSourceThumbnailMaxPixelSize;
    myValuesT[2] = (CFTypeRef) thumbnailSize;
    myKeysT[3] = kCGImageSourceCreateThumbnailFromImageAlways;
    myValuesT[3] = (CFTypeRef) kCFBooleanTrue;
    myKeysT[4] = kCGImageSourceShouldCache;
    myValuesT[4] = (CFTypeRef) kCFBooleanTrue;

    myOptionsT = CFDictionaryCreate(NULL, (const void **) myKeysT, (const void **) myValuesT, 5
            , &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

    thumbnail = CGImageSourceCreateThumbnailAtIndex(myImageSource, 0, myOptionsT);

    CFRelease(thumbnailSize);
    CFRelease(myOptionsT);
    CFRelease(myImageSource);

    if( thumbnail == NULL ){
        NSLog(@"image thumbnail is null");
        if( aError != NULL ) *aError = [NSError errorWithDomain:WD_ASYNC_IMAGE_ERROR_DOMAIN code:-41 userInfo:nil];
        return NULL;
    }
    [imagePath stopAccessingSecurityScopedResource];
    return thumbnail;
}

@end
