//
//  FFVideoPlayer.m
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/20.
//

#import "FFVideoPlayer.h"

@interface FFVideoPlayer()
@property (nonatomic, assign)NSInteger fps;
@property (nonatomic, strong)id<FFVideoRender> render;
@end
@implementation FFVideoPlayer {
    dispatch_source_t video_render_timer;
    dispatch_queue_t video_render_dispatch_queue;
}

- (instancetype)initWithQueue:(dispatch_queue_t)queue
                       render:(nonnull id<FFVideoRender>)videoRender
                          fps:(int)fps
                     delegate:(id<FFVideoPlayerDelegate>)delegate {
    self = [super init];
    if (self) {
        self->video_render_dispatch_queue = queue;
        self.fps = fps;
        self.render = videoRender;
        self.delegate = delegate;
    }
    return self;
}

#pragma mark - Private
- (void)playNextVideoFrame {
    [self.delegate readNextVideoFrame];
}
- (void)startVideoRender {
    if(self->video_render_timer) {
        dispatch_source_cancel(self->video_render_timer);
    }
    self->video_render_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, video_render_dispatch_queue);
    dispatch_source_set_timer(self->video_render_timer, dispatch_walltime(NULL, 0),
                              1.0 / self.fps * NSEC_PER_SEC,
                              1.0 / self.fps * NSEC_PER_SEC);
    dispatch_source_set_event_handler(self->video_render_timer, ^{
        [self playNextVideoFrame];
    });
    dispatch_resume(self->video_render_timer);
}

- (void)stopVideoRender {
    if(self->video_render_timer) dispatch_cancel(self->video_render_timer);
}
#pragma mark - Public
- (void)startPlay {
    [self startVideoRender];
}
- (void)stopPlay {
    [self stopVideoRender];
}
- (void)renderFrame:(AVFrame *)frame {
    [self.render displayWithFrame:frame];
}
- (AVPixelFormat)pixelFormat {
    return [self.render pixelFormat];
}
@end
