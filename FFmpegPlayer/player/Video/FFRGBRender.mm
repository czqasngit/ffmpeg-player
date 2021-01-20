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
    dispatch_queue_t display_rgb_queue;
}


- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        display_rgb_queue = dispatch_queue_create("display rgb queue",
                                                  DISPATCH_QUEUE_SERIAL);
        [self setupImageView];
    }
    return self;
}

- (void)setupImageView {
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
- (void)displayWithFrame:(AVFrame *)rgbFrame {
    int linesize = rgbFrame->linesize[0];
    int videoHeight = rgbFrame->height;
    int videoWidth = rgbFrame->width;
    int len = (linesize * videoHeight);
    UInt8 *bytes = (UInt8 *)malloc(len);
    memcpy(bytes, rgbFrame->data[0], len);
    dispatch_async(display_rgb_queue, ^{
        CFDataRef data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, bytes, len, kCFAllocatorNull);
        if(!data) {
            NSLog(@"create CFDataRef failed.");
            free(bytes);
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
        NSSize size = NSSizeFromCGSize(CGSizeMake(videoWidth, videoHeight));
        NSImage *image = [[NSImage alloc] initWithCGImage:imageRef
                                                     size:size];
        CGImageRelease(imageRef);
        CGColorSpaceRelease(colorSpaceRef);
        CGDataProviderRelease(provider);
        CFRelease(data);
        free(bytes);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            @autoreleasepool {
                self.imageView.image = image;
            }
        });
        
    });
}
- (AVPixelFormat)pixelFormat {
    return AV_PIX_FMT_RGB24;
}
@end
