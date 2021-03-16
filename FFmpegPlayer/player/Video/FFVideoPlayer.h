//
//  FFVideoPlayer.h
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/20.
//

#import <Foundation/Foundation.h>
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
}
#import "FFVideoRender.h"

NS_ASSUME_NONNULL_BEGIN

@protocol FFVideoPlayerDelegate <NSObject>
- (void)readNextVideoFrame;
- (void)updateVideoClock:(float)pts duration:(float)duration;
@end
@interface FFVideoPlayer : NSObject
@property (nonatomic, weak)id<FFVideoPlayerDelegate> delegate;
- (instancetype)initWithQueue:(dispatch_queue_t)queue
                       render:(nonnull id<FFVideoRender>)videoRender
                          fps:(int)fps
                        avctx:(AVCodecContext *)avctx
                       stream:(AVStream *)stream
                     delegate:(id<FFVideoPlayerDelegate>)delegate;
- (void)renderFrame:(AVFrame *)frame;
- (void)start;
- (void)stop;
- (void)pause;
- (void)resume;
- (AVPixelFormat)pixelFormat;
@end

NS_ASSUME_NONNULL_END
