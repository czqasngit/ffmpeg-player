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
@property (nonatomic, assign)double unit;
@property (nonatomic, assign)double pts;
@property (nonatomic, assign)double duration;
- (instancetype)init;
- (AVFrame *)frame;
@end

NS_ASSUME_NONNULL_END
