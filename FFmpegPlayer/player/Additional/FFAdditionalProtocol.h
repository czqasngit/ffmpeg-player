//
//  FFControlView.h
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/2/9.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol FFAdditionalProtocol <NSObject>
- (void)receiveDuration:(float)duration;
@end

NS_ASSUME_NONNULL_END
