//
//  FFAudioQueuePlayer.h
//  FFmpegPlayer
//
//  Created by Mark on 2021/1/16.
//

#import <Foundation/Foundation.h>
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswresample/swresample.h>
}
#import <AudioToolbox/AudioToolbox.h>
NS_ASSUME_NONNULL_BEGIN

@interface FFAudioQueuePlayer : NSObject
- (instancetype)initWithAudioCodecContext:(AVCodecContext *)audioCodecContext;
- (void)receiveFrame:(AVFrame *)frame;
- (void)reuseAudioQueueBuffer:(AudioQueueBufferRef)aqBuffer;
- (void)playNextFrame;
- (void)play;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
