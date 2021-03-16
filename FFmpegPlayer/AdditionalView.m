//
//  AdditionalView.m
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/2/9.
//

#import "AdditionalView.h"

@interface _NSSlider : NSSlider
@property (nonatomic, strong)void(^mouseDownBlock)(void);
@end
@implementation _NSSlider

- (void)mouseDown:(NSEvent *)event {
    NSLog(@"滑动: 鼠标按下");
    self.mouseDownBlock();
    [super mouseDown:event];
}

@end

@interface AdditionalView()
@property (nonatomic, strong)NSView *container;
@property (nonatomic, strong)NSTextField *durationLabel;
@property (nonatomic, strong)NSTextField *currentTimeLabel;
@property (nonatomic, strong)_NSSlider *slider;
@property (nonatomic, strong)NSButton *playButton;
@property (nonatomic, strong)NSButton *nextButton;
@property (nonatomic, strong)NSButton *prevButton;
@property (nonatomic, assign)CGFloat duration;
@property (nonatomic, assign)CGFloat currentTime;
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
    [self addSubview:self.container];
    [self.container addSubview:self.slider];
    [self.container addSubview:self.durationLabel];
    [self.container addSubview:self.currentTimeLabel];
    [self.container addSubview:self.playButton];
    [self.container addSubview:self.nextButton];
    [self.container addSubview:self.prevButton];
}
- (void)_layout {
    
    [self.container.leadingAnchor constraintEqualToAnchor:self.leadingAnchor].active = YES;
    [self.container.trailingAnchor constraintEqualToAnchor:self.trailingAnchor].active = YES;
    [self.container.bottomAnchor constraintEqualToAnchor:self.bottomAnchor].active = YES;
    [self.container.heightAnchor constraintEqualToConstant:120.0f].active = YES;
    
    [self.slider.topAnchor constraintEqualToAnchor:self.container.topAnchor constant:30.0f].active = YES;
    [self.slider.leadingAnchor constraintEqualToAnchor:self.container.leadingAnchor constant:70.0f].active = YES;
    [self.slider.trailingAnchor constraintEqualToAnchor:self.container.trailingAnchor constant:-70.0f].active = YES;
    
    [self.durationLabel.centerYAnchor constraintEqualToAnchor:self.slider.centerYAnchor constant:0].active = YES;
    [self.durationLabel.trailingAnchor constraintEqualToAnchor:self.container.trailingAnchor constant:-10.0f].active = YES;
    
    [self.currentTimeLabel.centerYAnchor constraintEqualToAnchor:self.slider.centerYAnchor constant:0].active = YES;
    [self.currentTimeLabel.leadingAnchor constraintEqualToAnchor:self.container.leadingAnchor constant:10.0f].active = YES;
    
    [self.playButton.centerXAnchor constraintEqualToAnchor:self.container.centerXAnchor].active = YES;
    [self.playButton.bottomAnchor constraintEqualToAnchor:self.container.bottomAnchor constant:-20.0f].active = YES;
    [self.playButton.widthAnchor constraintEqualToConstant:40.0f].active = YES;
    [self.playButton.heightAnchor constraintEqualToConstant:40.0f].active = YES;
    
    [self.nextButton.leadingAnchor constraintEqualToAnchor:self.playButton.trailingAnchor constant:15.0f].active = YES;
    [self.nextButton.centerYAnchor constraintEqualToAnchor:self.playButton.centerYAnchor constant:0.0f].active = YES;
    [self.nextButton.widthAnchor constraintEqualToConstant:40.0f].active = YES;
    [self.nextButton.heightAnchor constraintEqualToConstant:40.0f].active = YES;
    
    [self.prevButton.trailingAnchor constraintEqualToAnchor:self.playButton.leadingAnchor constant:-15.0f].active = YES;
    [self.prevButton.centerYAnchor constraintEqualToAnchor:self.playButton.centerYAnchor constant:0.0f].active = YES;
    [self.prevButton.widthAnchor constraintEqualToConstant:40.0f].active = YES;
    [self.prevButton.heightAnchor constraintEqualToConstant:40.0f].active = YES;
}


#pragma mark - Lazy Loaded
- (NSView *)container {
    if(!_container) {
        _container = [[NSView alloc] init];
        _container.wantsLayer = YES;
        _container.layer.backgroundColor = [[NSColor blackColor] colorWithAlphaComponent:0.7f].CGColor;
//        _container.layer.cornerRadius = 2.0f;
        _container.translatesAutoresizingMaskIntoConstraints = NO;
    }
    return _container;
}
- (NSTextField *)durationLabel {
    if(!_durationLabel) {
        _durationLabel = [[NSTextField alloc] init];
        _durationLabel.wantsLayer = YES;
        _durationLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _durationLabel.layer.backgroundColor = [NSColor clearColor].CGColor;
        _durationLabel.backgroundColor = [NSColor clearColor];
        _durationLabel.textColor = [NSColor whiteColor];
        _durationLabel.alignment = NSTextAlignmentCenter;
        _durationLabel.editable = NO;
        _durationLabel.bordered = NO;
        _durationLabel.bezeled = NO;
        _durationLabel.stringValue = @"00:00";
        _durationLabel.font = [NSFont systemFontOfSize:16];
    }
    return _durationLabel;
}
- (NSTextField *)currentTimeLabel {
    if(!_currentTimeLabel) {
        _currentTimeLabel = [[NSTextField alloc] init];
        _currentTimeLabel.wantsLayer = YES;
        _currentTimeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _currentTimeLabel.layer.backgroundColor = [NSColor clearColor].CGColor;
        _currentTimeLabel.backgroundColor = [NSColor clearColor];
        _currentTimeLabel.textColor = [NSColor whiteColor];
        _currentTimeLabel.alignment = NSTextAlignmentCenter;
        _currentTimeLabel.editable = NO;
        _currentTimeLabel.bordered = NO;
        _currentTimeLabel.bezeled = NO;
        _currentTimeLabel.stringValue = @"00:00";
        _currentTimeLabel.font = [NSFont systemFontOfSize:16];
    }
    return _currentTimeLabel;
}
- (_NSSlider *)slider {
    if(!_slider) {
        _slider = [_NSSlider sliderWithTarget:self action:@selector(sliderAction:)];
        _slider.translatesAutoresizingMaskIntoConstraints = NO;
        _slider.wantsLayer = YES;
        _slider.continuous = NO;
        __weak typeof(self) ws = self;
        _slider.mouseDownBlock = ^{
            __strong typeof(ws) ss = ws;
            [ss.delegate pause];
        };
    }
    return _slider;
}

- (NSButton *)playButton {
    if(!_playButton) {
        _playButton = [[NSButton alloc] init];
        _playButton.translatesAutoresizingMaskIntoConstraints = NO;
        _playButton.imageScaling = NSScaleToFit;
        _playButton.wantsLayer = YES;
        [_playButton setImage:[NSImage imageNamed:@"play"]];
        _playButton.bezelStyle = NSBezelStyleTexturedSquare;
        [_playButton setTarget:self];
        [_playButton setAction:@selector(play:)];
    }
    return _playButton;
}
- (NSButton *)nextButton {
    if(!_nextButton) {
        _nextButton = [[NSButton alloc] init];
        _nextButton.translatesAutoresizingMaskIntoConstraints = NO;
        _nextButton.imageScaling = NSScaleToFit;
        _nextButton.wantsLayer = YES;
        _nextButton.bezelStyle = NSBezelStyleTexturedSquare;
        [_nextButton setImage:[NSImage imageNamed:@"next"]];
        [_nextButton setTarget:self];
        [_nextButton setAction:@selector(speed:)];
    }
    return _nextButton;
}
- (NSButton *)prevButton {
    if(!_prevButton) {
        _prevButton = [[NSButton alloc] init];
        _prevButton.translatesAutoresizingMaskIntoConstraints = NO;
        _prevButton.imageScaling = NSScaleToFit;
        _prevButton.wantsLayer = YES;
        _prevButton.bezelStyle = NSBezelStyleTexturedSquare;
        [_prevButton setImage:[NSImage imageNamed:@"prev"]];
        [_prevButton setTarget:self];
        [_prevButton setAction:@selector(fastBackward:)];
    }
    return _prevButton;
}

#pragma mark - Action
- (void)play:(NSButton *)sender {
    [self.delegate togglePlayAction];
}
- (void)fastBackward:(id)sender {
    [self.delegate seekTo:self.currentTime - 3];
}
- (void)speed:(id)sender {
    [self.delegate seekTo:self.currentTime + 3];
}
- (void)sliderAction:(NSSlider *)sender {
    NSLog(@"滑动: %f", sender.floatValue);
    [self.delegate seekTo:sender.floatValue];
}
#pragma mark - FFPlayerDelegate
- (void)playerReadyToPlay:(float)duration {
    self.duration = duration;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.durationLabel.stringValue = [NSString stringWithFormat:@"%02d:%02d", (int)(duration / 60), (int)duration % 60];
        self.slider.maxValue = duration;
        self.slider.minValue = 0;
    });
}
- (void)playerCurrentTime:(float)currentTime {
    self.currentTime = currentTime;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.currentTimeLabel.stringValue = [NSString stringWithFormat:@"%02d:%02d", (int)(currentTime / 60), (int)currentTime % 60];
        self.slider.floatValue = currentTime;
    });
}
- (void)playerStateChanged:(FFPlayState)playState {
    dispatch_async(dispatch_get_main_queue(), ^{
        switch (playState) {
            case FFPlayStatePlaying:
                self.playButton.image = [NSImage imageNamed:@"pause"];
                break;
            case FFPlayStatePause:
                self.playButton.image = [NSImage imageNamed:@"play"];
                break;
            default:
                break;
        }
    });
}
+ (BOOL)requiresConstraintBasedLayout { return YES; }
@end
