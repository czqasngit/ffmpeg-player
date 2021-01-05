//
//  RGBDisplayView.m
//  FFDemo-MacUI
//
//  Created by Mark on 2020/11/29.
//

#import "FFRGBRender.h"
#import <CoreImage/CoreImage.h>

@interface FFRGBRender()
@property (nonatomic, strong)NSImageView *imageView;
@end
@implementation FFRGBRender {
    dispatch_queue_t _display_rgb_queue;
}


- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _display_rgb_queue = dispatch_queue_create("display rgb queue", DISPATCH_QUEUE_SERIAL);
        [self _setupImageView];
    }
    return self;
}

- (void)_setupImageView {
    if(!_imageView) {
        _imageView = [[NSImageView alloc] init];
        [self addSubview:_imageView];
        _imageView.translatesAutoresizingMaskIntoConstraints = NO;
        [_imageView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor].active = YES;
        [_imageView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor].active = YES;
        [_imageView.topAnchor constraintEqualToAnchor:self.topAnchor].active = YES;
        [_imageView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor].active = YES;
    }
}
#pragma mark - Public
- (void)displayWithAVFrame:(AVFrame *)rgbFrame {
    int linesize = rgbFrame->linesize[0];
    int videoHeight = rgbFrame->height;
    int videoWidth = rgbFrame->width;
    int len = (linesize * videoHeight);
    UInt8 *bytes = (UInt8 *)malloc(len * sizeof(UInt8));
    memcpy(bytes, rgbFrame->data[0], len);
    dispatch_async(_display_rgb_queue, ^{
        CFDataRef data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, bytes, len, kCFAllocatorNull);
        if(!data) {
            NSLog(@"create CFDataRef failed.");
            return;
        }
        if(CFDataGetLength(data) == 0) {
            CFRelease(data);
            free(bytes);
            return;
        }
        CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
        CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
        CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
        CGImageRef imageRef = CGImageCreate(videoWidth,
                                            videoHeight,
                                            8,
                                            3 * 8,
                                            linesize,
                                            colorSpaceRef,
                                            bitmapInfo,
                                            provider,
                                            NULL,
                                            YES,
                                            kCGRenderingIntentDefault);
        NSImage *image = [[NSImage alloc] initWithCGImage:imageRef
                                                     size:NSSizeFromCGSize(CGSizeMake(videoWidth,   videoHeight))];
        dispatch_async(dispatch_get_main_queue(), ^{
            @autoreleasepool {
                self.imageView.image = image;
            }
        });
        CGImageRelease(imageRef);
        CGColorSpaceRelease(colorSpaceRef);
        CGDataProviderRelease(provider);
        CFRelease(data);
        free(bytes);
    });
}
- (AVPixelFormat)piexlFormat {
    return AV_PIX_FMT_RGB24;
}
@end
