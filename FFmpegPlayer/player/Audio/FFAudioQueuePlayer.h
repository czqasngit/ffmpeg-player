//
//  FFAudioQueuePlayer.h
//  FFmpegPlayer
//
//  Created by Mark on 2021/1/16.
//

#import <Foundation/Foundation.h>
extern "C" {
#include <libavformat/avformat.h>
}
#import <AudioToolbox/AudioToolbox.h>
NS_ASSUME_NONNULL_BEGIN

@protocol FFAudioQueuePlayerDelegate <NSObject>
- (void)readNextAudioFrame:(AudioQueueBufferRef)aqBuffer;
@end
@interface FFAudioQueuePlayer : NSObject
- (instancetype)initWithBufferSize:(int)bufferSize
                      sampleFormat:(AVSampleFormat)sampleFormat
                        sampleRate:(int)sampleRate
                          delegate:(id<FFAudioQueuePlayerDelegate>)delegate;
- (void)receiveData:(uint8_t *)data length:(int)length aqBuffer:(AudioQueueBufferRef)aqBuffer;
- (void)reuseAudioQueueBuffer:(AudioQueueBufferRef)aqBuffer;
- (void)play;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
