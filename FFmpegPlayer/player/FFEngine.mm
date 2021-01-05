//
//  FFEngine.m
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/4.
//

#import "FFEngine.h"
#import "FFMediaVideoContext.h"
#import "FFMediaAudioContext.h"

#import "FFVideoRender.h"

@interface FFEngine()
@property (nonatomic, strong)FFMediaVideoContext *mediaVideo;
@property (nonatomic, strong)FFMediaAudioContext *mediaAudio;
@property (nonatomic, strong)id<FFVideoRender> videoRender;
@property (nonatomic, strong)NSTimer *displayTimer;
@end
@implementation FFEngine {
    AVFormatContext *formatContext;
    dispatch_queue_t _decode_queue;
    AVPacket *packet;
}

- (instancetype)initWithVideoRender:(id<FFVideoRender>)videoRender {
    self = [super init];
    if (self) {
        self.videoRender = videoRender;
        _decode_queue = dispatch_queue_create("decode queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}
- (void)dealloc {
    if(formatContext) {
        avformat_close_input(&formatContext);
    }
    
    if(packet) {
        av_packet_unref(packet);
        av_packet_free(&packet);
    }
}
- (BOOL)setup:(const char *)url {
    /// formatContet: AVFormatContext,保存了音视频文件信息
    /// url: 需要打开的音视频文件地址
    /// fmt: 指定打开的音视频文件的格式,如果不指定则自动推导
    /// options: 设置AVFormatContext的options,它的默认值定义在:libavformat/options_table.h
    /// 说明: AVFormatContext是一个AVClass,可以通过键值读取与设置定义的相关属性
    int ret = avformat_open_input(&formatContext, url, NULL, NULL);
    if(ret != 0) goto fail;
    /// formatContet: AVFormatContext,保存了音视频文件信息
    /// options: 如果配置了,则流信息会被保存到里面,这里不需要保存输入NULL
    ret = avformat_find_stream_info(formatContext, NULL);
    if(ret < 0) goto fail;
    if(formatContext->nb_streams == 0) goto fail;
    for(int i = 0; i < formatContext->nb_streams; i ++) {
        AVStream *stream = formatContext->streams[i];
        AVMediaType mediaType = stream->codecpar->codec_type;
        if(mediaType == AVMEDIA_TYPE_VIDEO) {
            _mediaVideo = [[FFMediaVideoContext alloc] initWithAVStream:stream formatContext:formatContext fmt:[self.videoRender piexlFormat]];
            if(!_mediaVideo) goto fail;
        } else if(mediaType == AVMEDIA_TYPE_AUDIO) {
            _mediaAudio = [[FFMediaAudioContext alloc] initWithAVStream:stream formatContext:formatContext];
            if(!_mediaAudio) goto fail;
        }
    }
    self->packet = av_packet_alloc();
    if(self.displayTimer) {
        [self.displayTimer invalidate];
        self.displayTimer = NULL;
    }
    self.displayTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f / self.mediaVideo.fps
                                                         target:self
                                                       selector:@selector(displayNextFrame)
                                                       userInfo:NULL
                                                        repeats:YES];
    return YES;
fail:
    if(formatContext) {
        avformat_close_input(&formatContext);
    }
    return NO;
}

#pragma mark - Private
- (void)displayNextFrame {
    dispatch_async(_decode_queue, ^{
        bool stop = false;
        while (!stop) {
            av_packet_unref(self->packet);
            if(av_read_frame(self->formatContext, self->packet) >= 0) {
                if(self->packet->stream_index == self.mediaVideo.streamIndex) {
                    AVFrame *frame = [self.mediaVideo decodePacket:self->packet];
                    if(frame) {
                        [self.videoRender displayWithAVFrame:frame];
                        stop = YES;
                    }
                }
            } else {
                av_packet_unref(self->packet);
            }
        }
    });
}

@end
