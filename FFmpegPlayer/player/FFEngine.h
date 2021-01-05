//
//  FFEngine.h
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/4.
//

#import <Foundation/Foundation.h>
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavfilter/avfilter.h>
}
#import "FFVideoRender.h"

NS_ASSUME_NONNULL_BEGIN

@interface FFEngine : NSObject
- (instancetype)initWithVideoRender:(id<FFVideoRender>)videoRender;
- (BOOL)setup:(const char *)url;

@end

NS_ASSUME_NONNULL_END
