//
//  AdditionalView.m
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/2/9.
//

#import "AdditionalView.h"

@interface AdditionalView()
@property (nonatomic, strong)NSTextField *timeLabel;
@end
@implementation AdditionalView

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self _setup];
        [self _layout];
    }
    return self;
}
#pragma mark -
- (void)_setup {
    [self addSubview:self.timeLabel];
}
- (void)_layout {
    [self.timeLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant: -20.0f].active = YES;
    [self.timeLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:20.0f].active = YES;
    [self.timeLabel.widthAnchor constraintEqualToConstant:130.0f].active = YES;
    [self.timeLabel.heightAnchor constraintEqualToConstant:44.0f].active = YES;
}
#pragma mark - Lazy Loaded
- (NSText *)timeLabel {
    if(!_timeLabel) {
        _timeLabel = [[NSTextField alloc] init];
        _timeLabel.wantsLayer = YES;
        _timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _timeLabel.layer.backgroundColor = [[NSColor blackColor] colorWithAlphaComponent:0.5f].CGColor;
        _timeLabel.textColor = [NSColor whiteColor];
        _timeLabel.alignment = NSTextAlignmentCenter;
        _timeLabel.editable = NO;
        _timeLabel.stringValue = @"00:00 / 00:00";
        _timeLabel.font = [NSFont systemFontOfSize:18];
        
    }
    return _timeLabel;
}

#pragma mark - FFAdditionalProtocol
- (void)receiveDuration:(float)duration {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.timeLabel.stringValue = [NSString stringWithFormat:@"00:00 / %02d:%02d", (int)(duration / 60), (int)duration % 60];
    });
}

+ (BOOL)requiresConstraintBasedLayout { return YES; }
@end
