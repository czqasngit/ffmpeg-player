//
//  FFPlayer.m
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/4.
//

#import "FFPlayer.h"
#import "FFEngine.h"
#import "FFRGBRender.h"
#import "FFVideoRender.h"

@interface FFPlayer()
@property (nonatomic, strong)FFEngine *engine;
@property (nonatomic, strong)id<FFVideoRender> videoRender;
@end
@implementation FFPlayer

- (instancetype)init {
    self = [super init];
    if (self) {
        _videoRender = [[FFRGBRender alloc] init];
        _engine = [[FFEngine alloc] initWithVideoRender:self.videoRender];
    }
    return self;
}

#pragma mark -
- (BOOL)setupPlayer:(const char *)url {
    BOOL ret = [_engine setup:url];
    if(!ret) return NO;
    
    return YES;
}

#pragma mark - Private

#pragma mark - Public
- (BOOL)playWithUrl:(NSString *)url {
    if(![self setupPlayer:[url UTF8String]]) {
        return NO;
    }
    return YES;
}
- (NSView *)renderView {
    return (id)self.videoRender;
}
@end
