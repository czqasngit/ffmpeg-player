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
@property(nonatomic, assign)int64_t lastFramePts;
@end
@implementation FFMediaVideoContext {
    AVFormatContext *formatContext;
    AVStream *stream;
    AVCodec *codec;
    AVCodecContext *codecContext;
    int streamIndex;
    AVPixelFormat fmt;
    AVFrame *hwFrame;
    AVFrame *frame;
    AVBufferRef *hwDeviceContext;
    BOOL enableHWDecode;
    BOOL supportAudioToolBox;
}
- (void)dealloc {
    if(self->codecContext) {
        avcodec_close(codecContext);
        avcodec_free_context(&codecContext);
    }
    if(hwFrame) {
        av_frame_unref(hwFrame);
        av_frame_free(&hwFrame);
    }
    if(frame) {
        av_frame_unref(frame);
        av_frame_free(&frame);
    }
    if(hwDeviceContext) {
        av_buffer_unref(&hwDeviceContext);
    }
}
- (instancetype)initWithAVStream:(AVStream *)stream
                   formatContext:(nonnull AVFormatContext *)formatContext
                             fmt:(AVPixelFormat)fmt
                  enableHWDecode:(BOOL)enableHWDecode {
    self = [super init];
    if(self) {
        self->stream = stream;
        self->formatContext = formatContext;
        self->fmt = fmt;
        if(![self _setupWithEnableHWDecode:enableHWDecode]) {
            return NULL;
        }
        self.filter = [[FFFilter alloc] initWithCodecContext:codecContext
                                               formatContext:formatContext
                                                      stream:formatContext->streams[streamIndex]
                                                         fmt:fmt];
        if(!self.filter) {
            return NULL;
        }
        [self setupLastPacketPts];
        self->frame = av_frame_alloc();
    }
    return self;
}
#pragma mark -
- (BOOL)_setupWithEnableHWDecode:(BOOL)enableHWDecode {
    _enableHWDecode = enableHWDecode;
    int ret = 0;
    AVCodecParameters *codecParameters = stream->codecpar;
    self->codec = avcodec_find_decoder(codecParameters->codec_id);
    if(!(self->codec)) goto fail;
    self->codecContext = avcodec_alloc_context3(self->codec);
    if(!(self->codecContext)) goto fail;
    ret = avcodec_parameters_to_context(self->codecContext, codecParameters);
    if(ret < 0) goto fail;
    if(enableHWDecode) {
        int hwConfigIndex = 0;
        supportAudioToolBox = false;
        /// 判断当前解码器是否支持AV_HWDEVICE_TYPE_VIDEOTOOLBOX硬解
        /// 某些视频格式的视频解码器不支持
        while (true) {
            const AVCodecHWConfig *config = avcodec_get_hw_config(self->codec, hwConfigIndex);
            if(!config) break;
            if(config->device_type == AV_HWDEVICE_TYPE_VIDEOTOOLBOX) {
                supportAudioToolBox = true;
                break;
            }
            hwConfigIndex ++;
        }
        if(supportAudioToolBox) {
            /// 创建硬件解码上下文,并指定硬件解码的格式
            /// 由于已经在上面判断了当前环境中是否支持AV_HWDEVICE_TYPE_VIDEOTOOLBOX,这里直接指定
            ret = av_hwdevice_ctx_create(&hwDeviceContext, AV_HWDEVICE_TYPE_VIDEOTOOLBOX, NULL, NULL, 0);
            if(ret != 0) goto fail;
            self->codecContext->hw_device_ctx = self->hwDeviceContext;
            /// 告知硬件解码器,解码输出格式
            /// 这个回调函数在被调用时会给出一组当前AVCodec支持的解码格式
            /// 这个数组按解码性能从高到低排列®
            /// 开发者可以按需返回一个最合适的
            /// decode时,开发者不设置则使用av_hwdevice_ctx_create创建时指定的格式
            /// 不能设置成NULL
//            self->codecContext->get_format = NULL;
            self->hwFrame = av_frame_alloc();
        }
    }
    
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
- (void)setupLastPacketPts {
    int64_t duration = stream->duration;
    AVRational time_base = stream->time_base;
    AVRational fps = stream->avg_frame_rate;
    _lastFramePts = duration - time_base.den / fps.num;
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
- (BOOL)decodePacket:(AVPacket *)packet frame:(AVFrame **)frame {
    int ret = avcodec_send_packet(self.codecContext, packet);
    if(ret != 0) return NO;
    AVFrame *outputFrame = *frame;
    av_frame_unref(self->hwFrame);
    if(self.enableHWDecode && supportAudioToolBox) {
        ret = avcodec_receive_frame(self.codecContext, self->hwFrame);
        if(ret != 0) return NO;
        av_frame_unref(self->frame);
        ret = av_hwframe_transfer_data(self->frame, self->hwFrame, 0);
    } else {
        ret = avcodec_receive_frame(self.codecContext, self->frame);
        if(ret != 0) return NO;
    }
    if(ret != 0) return NO;
    if(self->frame->pts == AV_NOPTS_VALUE) {
        self->frame->pts = self->hwFrame->pts;
    }
    av_frame_unref(outputFrame);
    [self.filter getTargetFormatFrameWithInputFrame:self->frame
                                outputFrame:&outputFrame];
    return YES;
}
- (float)oneFrameDuration {
    float d = 1.0f / av_q2d(stream->avg_frame_rate);
    return d;
}
- (float)duration {
    return (stream->duration * av_q2d(stream->time_base));
}
@end
