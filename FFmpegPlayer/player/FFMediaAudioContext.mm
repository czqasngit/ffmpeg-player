//
//  FFMediaAudio.m
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/4.
//

#import "FFMediaAudioContext.h"

@interface FFMediaAudioContext()
@end
@implementation FFMediaAudioContext {
    AVFormatContext *formatContext;
    AVStream *stream;
    AVCodec *codec;
    AVCodecContext *codecContext;
    int streamIndex;
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
    NSLog(@"=================== Audio Information ===================");
    NSLog(@"Sample Rate: %d", codecContext->sample_rate);
    NSLog(@"FMT: %d, %s", codecContext->sample_fmt, av_get_sample_fmt_name(codecContext->sample_fmt));
    NSLog(@"Channels: %d", codecContext->channels);
    NSLog(@"Channel Layout: %llu", codecContext->channel_layout);
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
