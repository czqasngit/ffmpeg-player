//
//  FFQueueObject.h
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/18.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

@interface FFQueueAudioObject : NSObject
- (instancetype)initWithLength:(int)length;
- (uint8_t *)data;
- (int64_t)length;
- (void)updateLength:(int64_t)length;
@end

NS_ASSUME_NONNULL_END
