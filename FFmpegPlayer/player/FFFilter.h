//
//  FFFilter.h
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/5.
//

#import <Foundation/Foundation.h>
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavfilter/avfilter.h>
#include <libavfilter/buffersrc.h>
#include <libavfilter/buffersink.h>
#include <libavutil/opt.h>
}
@class FFMediaVideoContext;
NS_ASSUME_NONNULL_BEGIN

@interface FFFilter : NSObject
- (instancetype)initWithVideoContext:(FFMediaVideoContext *)videoContext
                       formatContext:(AVFormatContext *)formatContext
                              stream:(AVStream *)stream
                           outputFmt:(AVPixelFormat)outputFmt;
- (BOOL)transformFormatWithInputFrame:(AVFrame *)inputFrame outputFrame:(AVFrame **)outputFrame;
@end

NS_ASSUME_NONNULL_END
