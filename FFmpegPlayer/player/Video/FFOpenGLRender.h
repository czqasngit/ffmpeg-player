//
//  YUVOpenGLDisplayView.h
//  FFDemo-MacUI
//
//  Created by youxiaobin on 2020/12/17.
//

#import <Cocoa/Cocoa.h>
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavfilter/avfilter.h>
#include <libavfilter/buffersrc.h>
#include <libavfilter/buffersink.h>
#include <libavutil/opt.h>
}
#import "FFVideoRender.h"


NS_ASSUME_NONNULL_BEGIN

@interface FFOpenGLRender : NSOpenGLView<FFVideoRender>

@end

NS_ASSUME_NONNULL_END
