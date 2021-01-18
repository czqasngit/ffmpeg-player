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
#import "FFAudioQueuePlayer.h"
#import "FFQueue.h"
#import "FFQueueAudioObject.h"

#define MAX_AUDIO_FRAME_COUNT   30
#define MIN_AUDIO_FRAME_COUNT   10

#define MAX_VIDEO_FRAME_COUNT   90
#define MIN_VIDEO_FRAME_COUNT   30



@interface FFEngine()<FFAudioQueuePlayerDelegate>
@property (nonatomic, strong)FFMediaVideoContext *mediaVideo;
@property (nonatomic, strong)FFMediaAudioContext *mediaAudio;
@property (nonatomic, strong)id<FFVideoRender> videoRender;
@property (nonatomic, strong)FFAudioQueuePlayer *audioPlayer;
@property (nonatomic, strong)NSCondition *decodeCondition;
@property (nonatomic, strong)NSCondition *playCondition;
@property (nonatomic, strong)FFQueue *videoQueue;
@property (nonatomic, strong)FFQueue *audioQueue;
@end
@implementation FFEngine {
    AVFormatContext *formatContext;
    dispatch_queue_t decode_queue;
    dispatch_queue_t play_queue;
    AVPacket *packet;
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
- (instancetype)initWithVideoRender:(id<FFVideoRender>)videoRender {
    self = [super init];
    if (self) {
        self.videoRender = videoRender;
        self->decode_queue = dispatch_queue_create("decode queue", DISPATCH_QUEUE_SERIAL);
        self->play_queue = dispatch_queue_create("audio queue", DISPATCH_QUEUE_SERIAL);
        self.decodeCondition = [[NSCondition alloc] init];
        self.playCondition = [[NSCondition alloc] init];
        self.videoQueue = [[FFQueue alloc] init];
        self.audioQueue = [[FFQueue alloc] init];
        self->packet = av_packet_alloc();
    }
    return self;
}
- (BOOL)setup:(const char *)url enableHWDecode:(BOOL)enableHWDecode {
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
    if(![self setupMediaContextWithEnableHWDecode:enableHWDecode]) goto fail;
    [self startDecode];
    [self.audioPlayer play];
    return YES;
fail:
    if(formatContext) {
        avformat_close_input(&formatContext);
    }
    return NO;
}

#pragma mark -
- (BOOL)setupMediaContextWithEnableHWDecode:(BOOL)enableHWDecode {
    for(int i = 0; i < formatContext->nb_streams; i ++) {
        AVStream *stream = formatContext->streams[i];
        AVMediaType mediaType = stream->codecpar->codec_type;
        if(mediaType == AVMEDIA_TYPE_VIDEO) {
            _mediaVideo = [[FFMediaVideoContext alloc] initWithAVStream:stream
                                                          formatContext:formatContext
                                                                    fmt:[self.videoRender piexlFormat] enableHWDecode:enableHWDecode];
            if(!_mediaVideo) return NO;
        } else if(mediaType == AVMEDIA_TYPE_AUDIO) {
            _mediaAudio = [[FFMediaAudioContext alloc] initWithAVStream:stream formatContext:formatContext];
            self.audioPlayer = [[FFAudioQueuePlayer alloc] initWithBufferSize:_mediaAudio.bufferSize
                                                                 sampleFormat:_mediaAudio.playSampleFormat
                                                                   sampleRate:_mediaAudio.rate
                                                                     delegate:self];
            if(!_mediaAudio) return NO;
        }
    }
    return YES;
}

#pragma mark - Private
- (void)startDecode {
    dispatch_async(decode_queue, ^{
        while (true) {
            if([self.audioQueue count] >= MAX_AUDIO_FRAME_COUNT) {
                [self.decodeCondition wait];
            }
            av_packet_unref(self->packet);
            if(av_read_frame(self->formatContext, self->packet) >= 0) {
                if(self->packet->stream_index == self.mediaVideo.streamIndex) {
                    AVFrame *frame = [self.mediaVideo decodePacket:self->packet];
                    if(frame) {
//                        _FFFrameObject *obj = [[_FFFrameObject alloc] init:frame];
//                        [self.videoQueue enqueue:obj];
                    }
                } else if(self->packet->stream_index == self.mediaAudio.streamIndex) {
                    FFQueueAudioObject *obj = [[FFQueueAudioObject alloc] initWithLength:self.mediaAudio.bufferSize];
                    uint8_t *buffer = obj.data;
                    [self.mediaAudio decodePacket:self->packet outBuffer:&buffer];
                    [self.audioQueue enqueue:obj];
                    if(self.audioQueue.count >= MIN_AUDIO_FRAME_COUNT) {
                        [self.playCondition signal];
                    }
                }
            }
        }
    });
}

- (void)readNextAudioFrame:(AudioQueueBufferRef)aqBuffer {
    dispatch_async(play_queue, ^{
        if(self.audioQueue.count < MIN_AUDIO_FRAME_COUNT) {
            NSLog(@"音频不够,阻塞");
            [self.playCondition wait];
        }
        FFQueueAudioObject *obj = [self.audioQueue dequeue];
        [self.audioPlayer receiveData:obj.data length:obj.length aqBuffer:aqBuffer];
        if(self.audioQueue.count < MAX_AUDIO_FRAME_COUNT) {
            [self.decodeCondition signal];
        }
    });
}

@end
