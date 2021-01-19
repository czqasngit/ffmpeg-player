//
//  FFQueueObject.m
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/18.
//

#import "FFQueueVideoObject.h"

@implementation FFQueueVideoObject {
    AVFrame *frame;
}
- (void)dealloc {
    if(frame) {
        av_frame_free(&frame);
    }
}
- (instancetype)init {
    self = [super init];
    if (self) {
        self->frame = av_frame_alloc();
    }
    return self;
}
- (AVFrame *)frame {
    return self->frame;
}

@end
