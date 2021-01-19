//
//  FFQueueObject.h
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/18.
//

#import <Foundation/Foundation.h>
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
}
NS_ASSUME_NONNULL_BEGIN

@interface FFQueueVideoObject : NSObject
- (instancetype)init;
- (AVFrame *)frame;
@end

NS_ASSUME_NONNULL_END
