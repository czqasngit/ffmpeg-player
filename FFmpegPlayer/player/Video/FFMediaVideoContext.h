//
//  FFMediaVideo.h
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/4.
//

#import <Foundation/Foundation.h>
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
}


NS_ASSUME_NONNULL_BEGIN

@interface FFMediaVideoContext : NSObject
@property(nonatomic, assign, readonly)BOOL enableHWDecode;
@property(nonatomic, assign, readonly)NSInteger streamIndex;
/// 最后一帧的pts
@property(nonatomic, assign, readonly)int64_t lastFramePts;

/// 初始化VideoContext
/// @param stream 视频流AVStream
/// @param formatContext AVFormatContext
/// @param fmt 需要显示的目标视频格式
- (instancetype)initWithAVStream:(AVStream *)stream
                   formatContext:(nonnull AVFormatContext *)formatContext
                             fmt:(AVPixelFormat)fmt
                  enableHWDecode:(BOOL)enableHWDecode;
- (AVCodecContext *)codecContext;
- (int)fps;
- (BOOL)decodePacket:(AVPacket *)packet frame:(AVFrame *_Nonnull*_Nonnull)frame;
- (float)oneFrameDuration;
- (float)duration;
@end

NS_ASSUME_NONNULL_END
