//
//  FFPlayer.h
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/4.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "FFPlayerDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface FFPlayer : NSObject
@property (nonatomic, strong)id<FFPlayerDelegate> ffPlayerDelegate;
/// 是否开启硬解码,默认关闭
/// 如果开启,ffmpeg在264 265的解码器会使用AudioToolBox利用GPU解码
- (BOOL)playWithUrl:(NSString *)url enableHWDecode:(BOOL)enableHWDecode;
- (void)pause;
- (void)resume;
- (void)stop;
- (void)seekTo:(float)time;
- (NSView *)renderView;
- (FFPlayState)playState;
@end

NS_ASSUME_NONNULL_END
