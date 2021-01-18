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


NS_ASSUME_NONNULL_BEGIN

@interface FFMediaAudioContext : NSObject
@property(nonatomic, assign)NSInteger streamIndex;
- (instancetype)initWithAVStream:(AVStream *)stream formatContext:(AVFormatContext *)formatContext;
- (void)decodePacket:(AVPacket *)packet outBuffer:(uint8_t **)buffer;
- (AVCodecContext *)codecContext;
- (int)bufferSize;
- (AVSampleFormat)playSampleFormat;
- (int)rate;
@end

NS_ASSUME_NONNULL_END
