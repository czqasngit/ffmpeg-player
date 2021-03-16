//
//  AdditionalView.h
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/2/9.
//

#import <Cocoa/Cocoa.h>
#import "FFPlayerDelegate.h"

NS_ASSUME_NONNULL_BEGIN
@protocol AdditionalViewDelegate <NSObject>
- (void)seekTo:(float)duration;
- (void)togglePlayAction;
- (void)pause;
@end
@interface AdditionalView : NSView<FFPlayerDelegate>
@property (nonatomic, weak)id<AdditionalViewDelegate> delegate;
@end

NS_ASSUME_NONNULL_END
