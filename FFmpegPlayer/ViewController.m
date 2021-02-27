//
//  ViewController.m
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/4.
//

#import "ViewController.h"
#import "FFPlayer.h"
#import "AdditionalView.h"

@interface ViewController()
@property (nonatomic, strong)FFPlayer *player;
@end
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _player = [[FFPlayer alloc] init];
    NSString *url = [[NSBundle mainBundle] pathForResource:@"long3e" ofType:@"mp4"];
//    NSString *url = [[NSBundle mainBundle] pathForResource:@"audio" ofType:@"mp3"];
    [self.view addSubview:_player.renderView];
    _player.renderView.frame = CGRectMake(0, 0, 1280, 720);
    AdditionalView *additionalView = [[AdditionalView alloc] initWithFrame:_player.renderView.frame];
    [self.view addSubview:additionalView];
    _player.additional = additionalView;
    [_player playWithUrl:url enableHWDecode:YES];
}


@end
