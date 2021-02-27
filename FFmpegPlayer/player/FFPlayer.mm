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
#import "FFOpenGLRender.h"
#import "FFMetalRender.h"


@interface FFPlayer()<FFEngineDelegate>
@property (nonatomic, strong)FFEngine *engine;
@property (nonatomic, strong)id<FFVideoRender> videoRender;
@end
@implementation FFPlayer

- (instancetype)init {
    self = [super init];
    if (self) {
        _videoRender = [[FFMetalRender alloc] init];
        _engine = [[FFEngine alloc] initWithVideoRender:self.videoRender delegate:self];
    }
    return self;
}

#pragma mark -
- (BOOL)setupPlayer:(const char *)url enableHWDecode:(BOOL)enableHWDecode {
    BOOL ret = [_engine play:url enableHWDecode:enableHWDecode];
    if(!ret) return NO;
    
    return YES;
}

#pragma mark - Private

#pragma mark - Public
- (BOOL)playWithUrl:(NSString *)url enableHWDecode:(BOOL)enableHWDecode {
    if(![self setupPlayer:[url UTF8String] enableHWDecode:enableHWDecode]) {
        return NO;
    }
    return YES;
}
- (void)stop {
    [_engine stop];
}
- (NSView *)renderView {
    return (id)self.videoRender;
}

#pragma mark - FFEngineDelegate
- (void)readyToPlay:(float)duration {
    if([self.additional respondsToSelector:@selector(receiveDuration:)]) {
        [self.additional receiveDuration:duration];
    }
}
@end
