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
        _videoRender = [[FFOpenGLRender alloc] init];
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
- (void)pause {
    [_engine pause];
}
- (void)resume {
    [_engine resume];
}
- (void)stop {
    [_engine stop];
}
- (void)seekTo:(float)time {
    [self.engine seekTo:time];
}
- (FFPlayState)playState {
    return [_engine playState];
}
- (NSView *)renderView {
    return (id)self.videoRender;
}

#pragma mark - FFEngineDelegate
- (void)readyToPlay:(float)duration {
    if([self.ffPlayerDelegate respondsToSelector:@selector(playerReadyToPlay:)]) {
        [self.ffPlayerDelegate playerReadyToPlay:duration];
    }
}
- (void)playCurrentTime:(float)currentTime {
    if([self.ffPlayerDelegate respondsToSelector:@selector(playerCurrentTime:)]) {
        [self.ffPlayerDelegate playerCurrentTime:currentTime];
    }
}
- (void)playStateChanged:(FFPlayState)state {
    if([self.ffPlayerDelegate respondsToSelector:@selector(playerStateChanged:)]) {
        [self.ffPlayerDelegate playerStateChanged:state];
    }
}
@end
