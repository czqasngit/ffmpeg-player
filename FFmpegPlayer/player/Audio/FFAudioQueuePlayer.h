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
@end
@interface FFAudioQueuePlayer : NSObject
- (instancetype)initWithAudioInformation:(FFAudioInformation)audioInformation
                                delegate:(id<FFAudioQueuePlayerDelegate>)delegate;
- (void)receiveData:(uint8_t *)data length:(int)length aqBuffer:(AudioQueueBufferRef)aqBuffer;
- (void)reuseAudioQueueBuffer:(AudioQueueBufferRef)aqBuffer;
- (void)play;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
