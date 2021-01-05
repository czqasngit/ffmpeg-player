//
//  FFPlayer.h
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/4.
//

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

@interface FFPlayer : NSObject
- (BOOL)playWithUrl:(NSString *)url;
@end

NS_ASSUME_NONNULL_END
