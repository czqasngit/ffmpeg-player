//
//  RGBDisplayView.h
//  FFDemo-MacUI
//
//  Created by Mark on 2020/11/29.
//

#import <AppKit/AppKit.h>
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
}
#import "FFVideoRender.h"

NS_ASSUME_NONNULL_BEGIN

@interface FFRGBRender : NSView<FFVideoRender>

@end

NS_ASSUME_NONNULL_END
