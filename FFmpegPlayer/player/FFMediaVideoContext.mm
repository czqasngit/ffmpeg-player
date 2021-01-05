//
//  FFMediaVideo.m
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/4.
//

#import "FFMediaVideoContext.h"

@interface FFMediaVideoContext()
@end
@implementation FFMediaVideoContext {
    AVFormatContext *formatContext;
    AVStream *stream;
    AVCodec *codec;
    AVCodecContext *codecContext;
    int streamIndex;
}
- (void)dealloc {
    if(self->codecContext) {
        avcodec_close(codecContext);
        avcodec_free_context(&codecContext);
    }
}
- (instancetype)initWithAVStream:(AVStream *)stream formatContext:(nonnull AVFormatContext *)formatContext {
    self = [super init];
    if(self) {
        self->stream = stream;
        self->formatContext = formatContext;
        if(![self _setup]) {
            return NULL;
        }
    }
    return self;
}
#pragma mark -
- (BOOL)_setup {
    int ret = 0;
    AVCodecParameters *codecParameters = stream->codecpar;
    self->codec = avcodec_find_decoder(codecParameters->codec_id);
    if(!(self->codec)) goto fail;
    self->codecContext = avcodec_alloc_context3(self->codec);
    if(!(self->codecContext)) goto fail;
    ret = avcodec_parameters_to_context(self->codecContext, codecParameters);
    if(ret < 0) goto fail;
    ret = avcodec_open2(self->codecContext, self->codec, NULL);
    if(ret < 0) goto fail;
    NSLog(@"=================== Video Information ===================");
    NSLog(@"FPS: %f", av_q2d(stream->avg_frame_rate));
    NSLog(@"Duration: %d Seconds", (int)(stream->duration * av_q2d(stream->time_base)));
    NSLog(@"Size: (%d, %d)", self->codecContext->width, self->codecContext->height);
    NSLog(@"Decodec: %s", self->codec->long_name);
    NSLog(@"=========================================================");
    return YES;
fail:
    return NO;
}

#pragma mark - Public
- (NSInteger)streamIndex {
    return self->stream->index;
}
@end
