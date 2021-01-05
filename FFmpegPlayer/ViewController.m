//
//  ViewController.m
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/4.
//

#import "ViewController.h"
#import "FFPlayer.h"

@interface ViewController()
@property (nonatomic, strong)FFPlayer *player;
@end
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _player = [[FFPlayer alloc] init];
    NSString *videoUrl = [[NSBundle mainBundle] pathForResource:@"1280x720" ofType:@"mp4"];
    [self.view addSubview:_player.renderView];
    _player.renderView.frame = CGRectMake(0, 0, 1280, 720);
    [_player playWithUrl:videoUrl];
}


@end
