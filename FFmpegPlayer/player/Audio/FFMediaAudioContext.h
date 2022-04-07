//
//  FFMediaAudio.h
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/4.
//

#import <Foundation/Foundation.h>
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswresample/swresample.h>
}
#import "FFAudioInformation.h"
#import "FFQueueAudioObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface FFMediaAudioContext : NSObject
@property(nonatomic, assign, readonly)NSInteger streamIndex;
/// 最后一帧的pts
@property(nonatomic, assign, readonly)int64_t lastFramePts;

- (instancetype)initWithAVStream:(AVStream *)stream formatContext:(AVFormatContext *)formatContext;
- (NSArray<FFQueueAudioObject *> *)decodePacket:(AVPacket *)packet;
- (AVCodecContext *)codecContext;
/// 播放器参数
- (FFAudioInformation)audioInformation;
- (float)oneFrameDuration;
@end

NS_ASSUME_NONNULL_END
