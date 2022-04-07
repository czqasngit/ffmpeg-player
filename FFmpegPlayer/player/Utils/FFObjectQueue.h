//
//  FFFrameQueue.h
//  FFmpegPlayer
//
//  Created by Mark on 2021/1/16.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFObjectQueue : NSObject
- (id _Nullable)dequeue;
- (void)enqueue:(id)object;
- (NSInteger)count;
- (void)clean;
- (float)duration;
@end

NS_ASSUME_NONNULL_END
