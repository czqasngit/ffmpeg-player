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

@interface FFQueueAudioObject : NSObject
- (instancetype)initWithLength:(int)length;
- (uint8_t *)data;
- (int)length;
@end

NS_ASSUME_NONNULL_END
