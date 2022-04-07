//
//  ViewController.m
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/4.
//

#import "ViewController.h"
#import "FFPlayer.h"
#import "AdditionalView.h"

@interface ViewController()<AdditionalViewDelegate>
@property (nonatomic, strong)FFPlayer *player;
@end
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _player = [[FFPlayer alloc] init];
    NSString *url = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"ape"];
//    NSString *url = [[NSBundle mainBundle] pathForResource:@"audio" ofType:@"mp3"];
    [self.view addSubview:_player.renderView];
    _player.renderView.frame = CGRectMake(0, 0, 1280, 720);
    AdditionalView *additionalView = [[AdditionalView alloc] initWithFrame:_player.renderView.frame];
    additionalView.delegate = self;
    [self.view addSubview:additionalView];
    _player.ffPlayerDelegate = additionalView;
    [_player playWithUrl:url enableHWDecode:YES];
}

- (void)seekTo:(float)duration {
    [self.player seekTo:duration];
}
- (void)togglePlayAction {
    if(self.player.playState == FFPlayStatePlaying) {
        [self.player pause];
    } else {
        [self.player resume];
    }
}
- (void)pause {
    [self.player pause];
}
@end
