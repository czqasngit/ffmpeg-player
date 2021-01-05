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
@property(nonatomic, assign)NSInteger streamIndex;
- (instancetype)initWithAVStream:(AVStream *)stream formatContext:(nonnull AVFormatContext *)formatContext;
- (AVCodecContext *)codecContext;
@end

NS_ASSUME_NONNULL_END
