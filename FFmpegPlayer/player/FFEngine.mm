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
#import "FFQueueVideoObject.h"

#error 这里应该设计成等待的秒
#define MAX_AUDIO_FRAME_COUNT   20
#define MIN_AUDIO_FRAME_COUNT   10

#define MAX_VIDEO_FRAME_COUNT   30
#define MIN_VIDEO_FRAME_COUNT   10



@interface FFEngine()
@property (nonatomic, strong)FFMediaVideoContext *mediaVideoContext;
@property (nonatomic, strong)FFMediaAudioContext *mediaAudioContext;
@property (nonatomic, strong)id<FFVideoRender> videoRender;
@property (nonatomic, strong)FFAudioQueuePlayer *audioPlayer;
@property (nonatomic, strong)NSCondition *decodeCondition;
@property (nonatomic, strong)NSCondition *audioPlayCondition;
@property (nonatomic, strong)NSCondition *videoRenderCondition;
@property (nonatomic, strong)FFQueue *videoFrameCacheQueue;
@property (nonatomic, strong)FFQueue *audioFrameCacheQueue;
@property (nonatomic, assign, getter=isDecodeComplete)BOOL decodeComplete;
@end
@implementation FFEngine {
    AVFormatContext *formatContext;
    dispatch_queue_t decode_dispatch_queue;
    dispatch_queue_t audio_play_dispatch_queue;
    dispatch_queue_t video_render_dispatch_queue;
    dispatch_source_t video_render_timer;
    AVPacket *packet;
}
- (void)dealloc {
    if(formatContext) {
        avformat_close_input(&formatContext);
        avformat_free_context(formatContext);
    }
    if(packet) {
        av_packet_unref(packet);
        av_packet_free(&packet);
    }
    [self stopVideoRender];
    [self stopAudioPlay];
}
- (instancetype)initWithVideoRender:(id<FFVideoRender>)videoRender {
    self = [super init];
    if (self) {
        self.videoRender = videoRender;
        self->decode_dispatch_queue = dispatch_queue_create("decode queue", DISPATCH_QUEUE_SERIAL);
        self->audio_play_dispatch_queue = dispatch_queue_create("audio play queue", DISPATCH_QUEUE_SERIAL);
        self->video_render_dispatch_queue = dispatch_queue_create("video render queue", DISPATCH_QUEUE_SERIAL);
        self->packet = av_packet_alloc();
        self.decodeCondition = [[NSCondition alloc] init];
        self.audioPlayCondition = [[NSCondition alloc] init];
        self.videoRenderCondition = [[NSCondition alloc] init];
        self.videoFrameCacheQueue = [[FFQueue alloc] init];
        self.audioFrameCacheQueue = [[FFQueue alloc] init];
    }
    return self;
}

#pragma mark - setup
- (BOOL)setupMediaContextWithEnableHWDecode:(BOOL)enableHWDecode {
    for(int i = 0; i < formatContext->nb_streams; i ++) {
        AVStream *stream = formatContext->streams[i];
        AVMediaType mediaType = stream->codecpar->codec_type;
        if(mediaType == AVMEDIA_TYPE_VIDEO) {
            _mediaVideoContext = [[FFMediaVideoContext alloc] initWithAVStream:stream
                                                                 formatContext:formatContext
                                                                           fmt:[self.videoRender piexlFormat]
                                                                enableHWDecode:enableHWDecode];
            if(!_mediaVideoContext) return NO;
        } else if(mediaType == AVMEDIA_TYPE_AUDIO) {
            _mediaAudioContext = [[FFMediaAudioContext alloc] initWithAVStream:stream
                                                                 formatContext:formatContext];
            self.audioPlayer = [[FFAudioQueuePlayer alloc] initWithAudioInformation:_mediaAudioContext.audioInformation
                                                                           delegate:(id)self];
            if(!_mediaAudioContext) return NO;
        }
    }
    return YES;
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
    [self decode];
    [self startAudioPlay];
    [self startVideoRender];
    return YES;
fail:
    if(formatContext) {
        avformat_close_input(&formatContext);
    }
    return NO;
}

#pragma mark - Decode
- (void)decode {
    dispatch_async(decode_dispatch_queue, ^{
        while (!self.isDecodeComplete) {
            /// Video与Audio缓冲帧超过最大数时暂停解码线程,等待唤醒
            if((!self.mediaAudioContext || [self.audioFrameCacheQueue count] >= MAX_AUDIO_FRAME_COUNT) &&
               (!self.mediaVideoContext || [self.videoFrameCacheQueue count] >= MAX_VIDEO_FRAME_COUNT)) {
                NSLog(@"Decode wait...");
                [self.decodeCondition wait];
            }
            av_packet_unref(self->packet);
            int ret_code = av_read_frame(self->formatContext, self->packet);
            if(ret_code >= 0) {
                if(self.mediaVideoContext && self->packet->stream_index == self.mediaVideoContext.streamIndex) {
                    uint64_t duration = self->formatContext->streams[self.mediaVideoContext.streamIndex]->duration;
                    FFQueueVideoObject *obj = [[FFQueueVideoObject alloc] init];
                    AVFrame *frame = obj.frame;
                    BOOL ret = [self.mediaVideoContext decodePacket:self->packet frame:&frame];
                    NSLog(@"【PTS】【Video】: %lld, duration: %lld, last: %lld, repeat: %d", frame->pts, duration, self->packet->duration, frame->repeat_pict);
                    if(ret) {
                        [self.videoFrameCacheQueue enqueue:obj];
                        /// 通知视频渲染队列可以继续渲染了
                        /// 如果视频渲染队列未暂停则无作用
                        if(self.videoFrameCacheQueue.count >= MIN_VIDEO_FRAME_COUNT) {
                            [self.videoRenderCondition signal];
                        }
                    }
                } else if(self.mediaAudioContext && self->packet->stream_index == self.mediaAudioContext.streamIndex) {
                    uint64_t duration = self->formatContext->streams[self.mediaAudioContext.streamIndex]->duration;
                    NSLog(@"【PTS】【Audio】: %lld, duration: %lld, last: %lld", self->packet->pts, duration, self->packet->duration);
                    int buffer_size = self.mediaAudioContext.audioInformation.buffer_size;
                    FFQueueAudioObject *obj = [[FFQueueAudioObject alloc] initWithLength:buffer_size];
                    uint8_t *buffer = obj.data;
                    BOOL ret = [self.mediaAudioContext decodePacket:self->packet outBuffer:&buffer];
                    if(ret) {
                        [self.audioFrameCacheQueue enqueue:obj];
                        /// 通知音频渲染队列可以继续渲染了
                        /// 如果音频渲染队列未暂停则无作用
                        if(self.audioFrameCacheQueue.count >= MIN_AUDIO_FRAME_COUNT) {
                            [self.audioPlayCondition signal];
                        }
                    }
                }
                self.decodeComplete = NO;
            } else {
                /// read end of file
                if(ret_code == AVERROR_EOF) {
                    self.decodeComplete = YES;
                }
            }
        }
        NSLog(@"Decode completed, read end of file.");
    });
}
#pragma mark - Video
- (void)startVideoRender {
    if(self->video_render_timer) {
        dispatch_source_cancel(self->video_render_timer);
    }
    if(!self.mediaVideoContext) return;
    self->video_render_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, video_render_dispatch_queue);
    dispatch_source_set_timer(self->video_render_timer, dispatch_walltime(NULL, 0),
                              1.0 / self.mediaVideoContext.fps * NSEC_PER_SEC,
                              1.0 / self.mediaVideoContext.fps * NSEC_PER_SEC);
    dispatch_source_set_event_handler(self->video_render_timer, ^{
        [self playNextVideoFrame];
    });
    dispatch_resume(self->video_render_timer);
}
- (void)stopVideoRender {
    if(self->video_render_timer) dispatch_cancel(self->video_render_timer);
}
- (void)playNextVideoFrame {
    dispatch_async(video_render_dispatch_queue, ^{
        if(self.videoFrameCacheQueue.count < MIN_VIDEO_FRAME_COUNT && !self.isDecodeComplete) {
            NSLog(@"Video is not enough, wait...");
            [self.videoRenderCondition wait];
        }
        FFQueueVideoObject *obj = [self.videoFrameCacheQueue dequeue];
        if(obj) {
            [self.videoRender displayWithFrame:obj.frame];
            if(self.videoFrameCacheQueue.count < MAX_VIDEO_FRAME_COUNT) {
                [self.decodeCondition signal];
            }
        } else {
            NSLog(@"Video frame render completed.");
            [self stopVideoRender];
        }
    });
}

#pragma mark - Audio
- (void)startAudioPlay {
    if(self.mediaAudioContext) {
        [self.audioPlayer play];
    }
}
- (void)stopAudioPlay {
    if(self.mediaAudioContext) {
        [self.audioPlayer stop];
    }
}
@end


@interface FFEngine (AudioPlay)<FFAudioQueuePlayerDelegate>
@end
@implementation FFEngine (AudioPlay)
- (void)readNextAudioFrame:(AudioQueueBufferRef)aqBuffer {
    dispatch_async(audio_play_dispatch_queue, ^{
        if(self.audioFrameCacheQueue.count < MIN_AUDIO_FRAME_COUNT && !self.isDecodeComplete) {
            NSLog(@"Audio is not enough, wait…");
            [self.audioPlayCondition wait];
        }
        FFQueueAudioObject *obj = [self.audioFrameCacheQueue dequeue];
        if(obj) {
            [self.audioPlayer receiveData:obj.data length:obj.length aqBuffer:aqBuffer];
            if(self.audioFrameCacheQueue.count < MAX_AUDIO_FRAME_COUNT) {
                [self.decodeCondition signal];
            }
        } else {
            NSLog(@"Audio frame play completed.");
            [self stopAudioPlay];
        }
    });
}
@end
