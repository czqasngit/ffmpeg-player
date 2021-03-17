//
//  FFAudioQueuePlayer.h
//  FFmpegPlayer
//
//  Created by Mark on 2021/1/16.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "FFAudioInformation.h"

NS_ASSUME_NONNULL_BEGIN

@protocol FFAudioQueuePlayerDelegate <NSObject>
- (void)readNextAudioFrame:(AudioQueueBufferRef)aqBuffer;
- (void)updateAudioClock:(float)pts duration:(float)duration;
@end
@interface FFAudioQueuePlayer : NSObject
- (instancetype)initWithAudioInformation:(FFAudioInformation)audioInformation
                                  stream:(AVStream *)stream
                                delegate:(id<FFAudioQueuePlayerDelegate>)delegate;
- (void)receiveData:(uint8_t *)data length:(int64_t)length
           aqBuffer:(AudioQueueBufferRef)aqBuffer
                pts:(float)pts
           duration:(float)duration;
- (void)reuseAudioQueueBuffer:(AudioQueueBufferRef)aqBuffer;
- (void)play;
- (void)stop;
- (void)pause;
- (void)resume;
- (void)cleanQueueCacheData;
@end

NS_ASSUME_NONNULL_END
