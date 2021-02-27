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

NS_ASSUME_NONNULL_BEGIN

@protocol FFEngineDelegate<NSObject>
- (void)readyToPlay:(float)duration;
@end

@interface FFEngine : NSObject
- (instancetype)initWithVideoRender:(id<FFVideoRender>)videoRender delegate:(id<FFEngineDelegate>)delegate;
- (BOOL)play:(const char *)url enableHWDecode:(BOOL)enableHWDecode;
- (void)stop;
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
