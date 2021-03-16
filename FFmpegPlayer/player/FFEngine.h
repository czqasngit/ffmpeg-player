//
//  FFEngine.h
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/4.
//

#import <Foundation/Foundation.h>
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavfilter/avfilter.h>
}
#import "FFVideoRender.h"
#import "FFAudioQueuePlayer.h"
#import "FFVideoPlayer.h"
#import "FFPlayState.h"

NS_ASSUME_NONNULL_BEGIN

@protocol FFEngineDelegate<NSObject>
- (void)readyToPlay:(float)duration;
- (void)playCurrentTime:(float)currentTime;
- (void)playStateChanged:(FFPlayState)state;
@end

@interface FFEngine : NSObject
@property (nonatomic, assign, readonly)FFPlayState playState;
- (instancetype)initWithVideoRender:(id<FFVideoRender>)videoRender delegate:(id<FFEngineDelegate>)delegate;
- (BOOL)play:(const char *)url enableHWDecode:(BOOL)enableHWDecode;
- (void)pause;
- (void)resume;
- (void)stop;
- (void)seekTo:(float)time;
@end

@interface FFEngine (Control)
- (void)startVideoPlay;
- (void)stopVideoPlay;
- (void)startAudioPlay;
- (void)stopAudioPlay;
@end

@interface FFEngine (Decode)
- (void)decode;
@end

@interface FFEngine (Video)<FFVideoPlayerDelegate>
@end

@interface FFEngine (Audio)<FFAudioQueuePlayerDelegate>
@end

NS_ASSUME_NONNULL_END
