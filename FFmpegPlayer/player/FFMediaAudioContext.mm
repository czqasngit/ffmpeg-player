//
//  FFMediaAudio.m
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/4.
//

#import "FFMediaAudioContext.h"

@interface FFMediaAudioContext()
@property (nonatomic, assign)FFAudioInformation audioInformation;
@property(nonatomic, assign)int64_t lastFramePts;

@end
@implementation FFMediaAudioContext {
    AVFormatContext *formatContext;
    AVStream *stream;
    AVCodec *codec;
    AVCodecContext *codecContext;
    int streamIndex;
    struct SwrContext *au_convert_ctx;
}

- (void)dealloc {
    if(au_convert_ctx) swr_free(&au_convert_ctx);
}
- (instancetype)initWithAVStream:(AVStream *)stream formatContext:(nonnull AVFormatContext *)formatContext {
    self = [super init];
    if(self) {
        self->stream = stream;
        self->formatContext = formatContext;
        if(![self setup]) {
            return NULL;
        }
        [self setupLastPacketPts];
        [self initializeSwr];
        
    }
    return self;
}
#pragma mark -
- (BOOL)setup {
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
- (void)setupLastPacketPts {
    int64_t duration = stream->duration;
    _lastFramePts = duration - stream->nb_frames;
}
- (void)initializeSwr {
    FFAudioInformation audioInformation = [self audioInformation];
    int64_t channel_layout = audioInformation.channels == 1 ? AV_CH_LAYOUT_MONO : AV_CH_LAYOUT_STEREO;
    /// 重采样成双通道,AV_SAMPLE_FMT_S16数据格式
    au_convert_ctx = swr_alloc_set_opts(NULL,
                                        channel_layout,
                                        audioInformation.format,
                                        audioInformation.rate,
                                        codecContext->channel_layout,
                                        codecContext->sample_fmt,
                                        codecContext->sample_rate,
                                        0,
                                        NULL);
    swr_init(au_convert_ctx);
}
#pragma mark - Public
- (NSInteger)streamIndex {
    return self->stream->index;
}
- (AVCodecContext *)codecContext {
    return self->codecContext;
}

- (BOOL)decodePacket:(AVPacket *)packet outBuffer:(uint8_t **)buffer {
    int ret = avcodec_send_packet(self->codecContext, packet);
    if(ret != 0) return NO;
    AVFrame *frame = av_frame_alloc();
    avcodec_receive_frame(self->codecContext, frame);
    if(ret != 0) {
        av_frame_unref(frame);
        av_frame_free(&frame);
        return NO;
    }
    swr_convert(au_convert_ctx, buffer, frame->nb_samples, (const uint8_t **)frame->data, frame->nb_samples);
    av_frame_unref(frame);
    av_frame_free(&frame);
    return YES;
}
- (FFAudioInformation)audioInformation {
    if(_audioInformation.rate == 0) {
        _audioInformation.format = AV_SAMPLE_FMT_S16;
        _audioInformation.channels = 2;
        _audioInformation.buffer_size = av_samples_get_buffer_size(NULL,
                                                                   _audioInformation.channels,
                                                                   codecContext->frame_size,
                                                                   _audioInformation.format, 1);
        _audioInformation.rate = self->codecContext->sample_rate;
        _audioInformation.bytesPerSample = _audioInformation.channels * av_get_bytes_per_sample(_audioInformation.format);
        _audioInformation.bitsPerChannel = 8 * av_get_bytes_per_sample(_audioInformation.format);
    }
    return _audioInformation;
}
@end
