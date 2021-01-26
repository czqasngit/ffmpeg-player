//
//  FFQueueObject.h
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/18.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

@interface FFQueueAudioObject : NSObject
@property (nonatomic, assign, readonly)float pts;
@property (nonatomic, assign, readonly)float duration;
- (instancetype)initWithLength:(int64_t)length pts:(float)pts duration:(float)duration;
- (uint8_t *)data;
- (int64_t)length;
- (void)updateLength:(int64_t)length;
@end

NS_ASSUME_NONNULL_END
