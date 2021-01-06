//
//  FFMediaVideo.m
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/4.
//

#import "FFMediaVideoContext.h"
#import "FFFilter.h"

@interface FFMediaVideoContext()
@property (nonatomic, strong)FFFilter *filter;
@end
@implementation FFMediaVideoContext {
    AVFormatContext *formatContext;
    AVStream *stream;
    AVCodec *codec;
    AVCodecContext *codecContext;
    int streamIndex;
    AVPixelFormat fmt;
    AVFrame *frame;
    AVFrame *outputFrame;
}
- (void)dealloc {
    if(self->codecContext) {
        avcodec_close(codecContext);
        avcodec_free_context(&codecContext);
    }
    if(frame) {
        av_frame_unref(frame);
        av_frame_free(&frame);
    }
    if(outputFrame) {
        av_frame_unref(outputFrame);
        av_frame_free(&outputFrame);
    }
}
- (instancetype)initWithAVStream:(AVStream *)stream
                   formatContext:(nonnull AVFormatContext *)formatContext
                             fmt:(AVPixelFormat)fmt {
    self = [super init];
    if(self) {
        self->stream = stream;
        self->formatContext = formatContext;
        self->fmt = fmt;
        if(![self _setup]) {
            return NULL;
        }
        self.filter = [[FFFilter alloc] initWithCodecContext:codecContext
                                               formatContext:formatContext
                                                      stream:formatContext->streams[streamIndex]
                                                   outputFmt:fmt];
        if(!self.filter) {
            return NULL;
        }
        self->frame = av_frame_alloc();
        self->outputFrame = av_frame_alloc();
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
- (AVCodecContext *)codecContext {
    return self->codecContext;
}
- (int)fps {
    return av_q2d(stream->avg_frame_rate);
}
- (AVFrame *)decodePacket:(AVPacket *)packet {
    int ret = avcodec_send_packet(self.codecContext, packet);
    av_frame_unref(self->frame);
    if(ret != 0) return NULL;
    ret = avcodec_receive_frame(self.codecContext, self->frame);
    if(ret == 0) {
        av_frame_unref(outputFrame);
        [self.filter getTargetFMTWithInputFrame:self->frame
                                    outputFrame:&outputFrame];
        NSLog(@"读取到视频帧:%lld", self->outputFrame->pts);
        return self->outputFrame;
    }
    return NULL;
}
@end
