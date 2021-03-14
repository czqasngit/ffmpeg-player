//
//  FFControlView.h
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/2/9.
//

#import <Foundation/Foundation.h>
#import "FFPlayState.h"

NS_ASSUME_NONNULL_BEGIN

@protocol FFPlayerDelegate <NSObject>
- (void)playerReadyToPlay:(float)duration;
- (void)playerCurrentTime:(float)currentTime;
- (void)playerStateChanged:(FFPlayState)playState;
@end

NS_ASSUME_NONNULL_END
