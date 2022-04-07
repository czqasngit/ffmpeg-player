//
//  FFEngine.m
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/4.
//

#import "FFEngine.h"
#import "FFMediaVideoContext.h"
#import "FFMediaAudioContext.h"
#import "FFObjectQueue.h"
#import "FFQueueAudioObject.h"
#import "FFQueueVideoObject.h"
#import <pthread.h>
#import "FFPlayState.h"

#define MAX_AUDIO_FRAME_DURATION   2
#define MIN_AUDIO_FRAME_DURATION   1
#define MAX_AUDIO_FRAME_COUNT      20
#define MIN_AUDIO_FRAME_COUNT      10

#define MAX_VIDEO_FRAME_DURATION   2
#define MIN_VIDEO_FRAME_DURATION   1

NS_INLINE void _NotifyWaitThreadWakeUp(NSCondition *condition) {
    /// To prevent current thread wait lead to wake up signal can’t reache to sleeping thread.
    /// Send signal dispatch on main thread.
    dispatch_queue_t queue = dispatch_get_main_queue();
    dispatch_async(queue, ^{
        [condition signal];
    });
}

NS_INLINE void _SleepThread(NSCondition *condition) {
    [condition wait];
}


@interface FFEngine()
@property (nonatomic, weak)id<FFEngineDelegate> delegate;
@property (nonatomic, strong)FFMediaVideoContext *mediaVideoContext;
@property (nonatomic, strong)FFMediaAudioContext *mediaAudioContext;
@property (nonatomic, strong)FFAudioQueuePlayer *audioPlayer;
@property (nonatomic, strong)FFVideoPlayer *videoPlayer;
@property (nonatomic, strong)id<FFVideoRender> videoRender;
@property (nonatomic, strong)NSCondition *decodeCondition;
@property (nonatomic, strong)NSCondition *audioPlayCondition;
@property (nonatomic, strong)NSCondition *videoRenderCondition;
@property (nonatomic, strong)FFObjectQueue *videoFrameCacheQueue;
@property (nonatomic, strong)FFObjectQueue *audioFrameCacheQueue;
@property (nonatomic, assign, getter=isDecodeComplete)BOOL decodeComplete;
@property (nonatomic, assign)FFPlayState playState;
@end
@implementation FFEngine {
    AVFormatContext *formatContext;
    dispatch_queue_t decode_dispatch_queue;
    dispatch_queue_t audio_play_dispatch_queue;
    dispatch_queue_t video_render_dispatch_queue;
    AVPacket *packet;
    /// lock shared variate
    pthread_mutex_t mutex;
    double video_clock;
    double tolerance_scope;
    double audio_clock;
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
    [self stopVideoPlay];
    [self stopAudioPlay];
}
- (instancetype)initWithVideoRender:(id<FFVideoRender>)videoRender delegate:(nonnull id<FFEngineDelegate>)delegate {
    self = [super init];
    if (self) {
        self->decode_dispatch_queue = dispatch_queue_create("decode queue", DISPATCH_QUEUE_SERIAL);
        self->audio_play_dispatch_queue = dispatch_queue_create("audio play queue", DISPATCH_QUEUE_SERIAL);
        self->video_render_dispatch_queue = dispatch_queue_create("video render queue", DISPATCH_QUEUE_SERIAL);
        self->packet = av_packet_alloc();
        self->video_clock = 0;
        self->tolerance_scope = 0;
        self->audio_clock = 0;
        pthread_mutex_init(&mutex, NULL);
        self.decodeCondition = [[NSCondition alloc] init];
        self.audioPlayCondition = [[NSCondition alloc] init];
        self.videoRenderCondition = [[NSCondition alloc] init];
        self.videoFrameCacheQueue = [[FFObjectQueue alloc] init];
        self.audioFrameCacheQueue = [[FFObjectQueue alloc] init];
        self.videoRender = videoRender;
        self.delegate = delegate;
    }
    return self;
}
- (BOOL)play:(const char *)url enableHWDecode:(BOOL)enableHWDecode {
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
    /// reset decode state
    self.decodeComplete = NO;
    [self start];
    return YES;
fail:
    if(formatContext) {
        avformat_close_input(&formatContext);
    }
    return NO;
}
- (BOOL)setupMediaContextWithEnableHWDecode:(BOOL)enableHWDecode {
    self.playState = FFPlayStateNone;
    for(int i = 0; i < formatContext->nb_streams; i ++) {
        AVStream *stream = formatContext->streams[i];
        AVMediaType mediaType = stream->codecpar->codec_type;
        if(mediaType == AVMEDIA_TYPE_VIDEO) {
            _mediaVideoContext = [[FFMediaVideoContext alloc] initWithAVStream:stream
                                                                 formatContext:formatContext
                                                                           fmt:[self.videoRender pixelFormat]
                                                                enableHWDecode:enableHWDecode];
            if(!_mediaVideoContext) return NO;
            self.videoPlayer = [[FFVideoPlayer alloc] initWithQueue:self->video_render_dispatch_queue
                                                             render:self.videoRender
                                                                fps:[self.mediaVideoContext fps]
                                                              avctx:self.mediaVideoContext.codecContext
                                                             stream:stream
                                                           delegate:(id)self];
            self->tolerance_scope = 1.0f / av_q2d(stream->avg_frame_rate);
        } else if(mediaType == AVMEDIA_TYPE_AUDIO) {
            _mediaAudioContext = [[FFMediaAudioContext alloc] initWithAVStream:stream
                                                                 formatContext:formatContext];
            if(!_mediaAudioContext) return NO;
            self.audioPlayer = [[FFAudioQueuePlayer alloc] initWithAudioInformation:_mediaAudioContext.audioInformation
                                                                             stream:stream
                                                                           delegate:(id)self];
        }
    }
    return YES;
}
- (void)start {
    self.playState = FFPlayStateLoading;
    [self decode];
    self->audio_clock = 0;
    self->video_clock = 0;
    
}
- (void)pause {
    [self.audioPlayer pause];
    [self.videoPlayer pause];
    self.playState = FFPlayStatePause;
}
- (void)resume {
    [self.audioPlayer resume];
    [self.videoPlayer resume];
    self.playState = FFPlayStatePlaying;
}
- (void)stop {
    [self stopVideoPlay];
    [self stopAudioPlay];
}
- (void)seekTo:(float)time {
    [self pause];
    [self.audioFrameCacheQueue clean];
    [self.videoFrameCacheQueue clean];
    pthread_mutex_lock(&(self->mutex));
    avcodec_flush_buffers([_mediaVideoContext codecContext]);
    avcodec_flush_buffers([_mediaAudioContext codecContext]);
    [self.audioPlayer cleanQueueCacheData];
    av_seek_frame(self->formatContext, -1, time * AV_TIME_BASE, AVSEEK_FLAG_BACKWARD);
    _NotifyWaitThreadWakeUp(self.decodeCondition);
    pthread_mutex_unlock(&(self->mutex));
    [self resume];
}
#pragma mark -
- (void)setPlayState:(FFPlayState)playState {
    if(_playState == playState) return;
    _playState = playState;
    if([self.delegate respondsToSelector:@selector(playStateChanged:)]) {
        [self.delegate playStateChanged:playState];
    }
}
@end

@implementation FFEngine (Decode)
- (void)decode {
    dispatch_async(decode_dispatch_queue, ^{
        while (true) {
            float audioCacheDuration = [self.audioFrameCacheQueue count] * [self.mediaAudioContext oneFrameDuration];
            float videoCacheDuration = [self.videoFrameCacheQueue count] * [self.mediaVideoContext oneFrameDuration];
            NSLog(@"【Cache】%f, %f, %ld", videoCacheDuration, audioCacheDuration, [self.audioFrameCacheQueue count]);
            /// Video与Audio缓冲帧都超过最大数时暂停解码线程,等待唤醒
            if((!self.mediaAudioContext || audioCacheDuration >= MAX_AUDIO_FRAME_DURATION || [self.audioFrameCacheQueue count] >= MAX_AUDIO_FRAME_COUNT) &&
               (!self.mediaVideoContext || videoCacheDuration >= MAX_VIDEO_FRAME_DURATION)) {
                NSLog(@"Decode wait...");
                if(self.playState == FFPlayStateLoading) {
                    self.playState = FFPlayStatePlaying;
                    [self startAudioPlay];
                    [self startVideoPlay];
                    if([self.delegate respondsToSelector:@selector(readyToPlay:)]) {
                        [self.delegate readyToPlay:[self.mediaVideoContext duration]];
                    }
                }
                _SleepThread(self.decodeCondition);
                NSLog(@"Decode resume");
            }
            av_packet_unref(self->packet);
            pthread_mutex_lock(&(self->mutex));
            int ret_code = av_read_frame(self->formatContext, self->packet);
            pthread_mutex_unlock(&(self->mutex));
            if(ret_code >= 0) {
                if(self.mediaVideoContext && self->packet->stream_index == self.mediaVideoContext.streamIndex) {
                    uint64_t duration = self->formatContext->streams[self.mediaVideoContext.streamIndex]->duration;
                    FFQueueVideoObject *obj = [[FFQueueVideoObject alloc] init];
                    float unit = av_q2d(self->formatContext->streams[self.mediaVideoContext.streamIndex]->time_base);
                    obj.unit = unit;
                    AVFrame *frame = obj.frame;
                    pthread_mutex_lock(&(self->mutex));
                    BOOL ret = [self.mediaVideoContext decodePacket:self->packet frame:&frame];
                    pthread_mutex_unlock(&(self->mutex));
                    obj.pts = obj.frame->pts * unit;
                    obj.duration = [self.mediaVideoContext oneFrameDuration];
                    if(self.videoFrameCacheQueue.count < 3) {
                        NSLog(@"[SEEK]当前的视频帧缓存数量:%ld, PTS:%f", self.videoFrameCacheQueue.count, obj.pts);
                    }
                    NSLog(@"【PTS】【Video】: %f, duration: %lld, last: %lld, repeat: %d", frame->pts * unit, duration, self->packet->duration, frame->repeat_pict);
                    if(ret) {
                        [self.videoFrameCacheQueue enqueue:obj];
                        videoCacheDuration = [self.videoFrameCacheQueue count] * [self.mediaVideoContext oneFrameDuration];
                        /// 通知视频渲染队列可以继续渲染了
                        /// 如果视频渲染队列未暂停则无作用
                        if(videoCacheDuration >= MIN_VIDEO_FRAME_DURATION) {
                            _NotifyWaitThreadWakeUp(self.videoRenderCondition);
                        }
                    }
                } else if(self.mediaAudioContext && self->packet->stream_index == self.mediaAudioContext.streamIndex) {
                    uint64_t duration = self->formatContext->streams[self.mediaAudioContext.streamIndex]->duration;
                    float unit = av_q2d(self.mediaAudioContext.codecContext->time_base);
                    NSLog(@"【PTS】【Audio】: %f, duration: %lld, last: %lld", self->packet->pts * unit, duration, self->packet->duration);
                    pthread_mutex_lock(&(self->mutex));
                    NSArray<FFQueueAudioObject *> *objs = [self.mediaAudioContext decodePacket:self->packet];
                    pthread_mutex_unlock(&(self->mutex));
                    if(objs.count > 0) {
                        for(FFQueueAudioObject *obj in objs) {
                            [self.audioFrameCacheQueue enqueue:obj];
                        }
                        audioCacheDuration = [self.audioFrameCacheQueue count] * [self.mediaAudioContext oneFrameDuration];

                        /// 通知音频渲染队列可以继续渲染了
                        /// 如果音频渲染队列未暂停则无作用
                        if(audioCacheDuration >= MIN_AUDIO_FRAME_DURATION || [self.audioFrameCacheQueue count] > MIN_AUDIO_FRAME_COUNT) {
                            _NotifyWaitThreadWakeUp(self.audioPlayCondition);
                        }
                    }
                }
            } else {
                /// read end of file
                if(ret_code == AVERROR_EOF) {
                    pthread_mutex_lock(&(self->mutex));
                    self.decodeComplete = YES;
                    pthread_mutex_unlock(&(self->mutex));
                }
            }
            pthread_mutex_lock(&(self->mutex));
            BOOL isDecodeComplete = self.isDecodeComplete;
            pthread_mutex_unlock(&(self->mutex));
            if(isDecodeComplete) break;
        }
        NSLog(@"Decode completed, read end of file.");
    });
}
@end

@implementation FFEngine (Control)
- (void)startVideoPlay {
    if(self.mediaVideoContext) {
        [self.videoPlayer start];
    }
}
- (void)stopVideoPlay {
    if(self.mediaVideoContext) {
        [self.videoPlayer stop];
    }
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


@implementation FFEngine (VideoPlay)
- (FFQueueVideoObject *_Nullable)_readNextVideoFrameBySyncAudio {
    pthread_mutex_lock(&(self->mutex));
    /// Current audio frame play end time.
    double ac = self->audio_clock;
    pthread_mutex_unlock(&(self->mutex));
    FFQueueVideoObject *obj = NULL;
    int readCount = 0;
    /// Read next video frame
    obj = [self.videoFrameCacheQueue dequeue];
    readCount ++;
    double vc = obj.pts + obj.duration;
    NSLog(@"[Sync] AC: %f, VC: %f, 差值: %f, syncDuration: %f", ac, vc, abs(ac - vc), self->tolerance_scope);
    if(ac - vc > self->tolerance_scope) {
        while (ac - vc > self->tolerance_scope) {
            FFQueueVideoObject *_nextObj = [self.videoFrameCacheQueue dequeue];
            if(!_nextObj) break;
            obj = _nextObj;
            vc = obj.pts + obj.duration;
            readCount ++;
        }
        NSLog(@"[Sync]音频太快,视频追赶跳过: %d 帧", (readCount - 1));
    } else if (vc - ac > self->tolerance_scope) {
        float sleep_time = vc - ac;
        NSLog(@"[Sync]视频太快,视频等待:%f, vc: %f, ac: %f", sleep_time, vc, ac);
        usleep(sleep_time * 1000 * 1000);
    } else {
        NSLog(@"[Sync]音频在误差允许范围内: %f, %f", abs(ac - vc), self->tolerance_scope);
    }
    return obj;
}
- (void)readNextVideoFrame {
    dispatch_async(video_render_dispatch_queue, ^{
        float videoCacheDuration = [self.videoFrameCacheQueue count] * [self.mediaVideoContext oneFrameDuration];
        pthread_mutex_lock(&(self->mutex));
        BOOL isDecodeComplete = self.isDecodeComplete;
        pthread_mutex_unlock(&(self->mutex));
        if(videoCacheDuration < MIN_VIDEO_FRAME_DURATION && !isDecodeComplete) {
            NSLog(@"Video is not enough, wait...");
            _NotifyWaitThreadWakeUp(self.decodeCondition);
            _SleepThread(self.videoRenderCondition);
        }
        if(videoCacheDuration < MAX_VIDEO_FRAME_DURATION) {
            _NotifyWaitThreadWakeUp(self.decodeCondition);
        }
        FFQueueVideoObject *obj = [self _readNextVideoFrameBySyncAudio];
        if(obj) {
            [self.videoPlayer renderFrame:obj.frame];
        } else {
            if(isDecodeComplete) {
                NSLog(@"Video frame render completed.");
                [self.videoPlayer stop];
            }
        }
    });
}
- (void)updateVideoClock:(float)pts duration:(float)duration {
    pthread_mutex_lock(&mutex);
    self->video_clock = pts + duration;
    pthread_mutex_unlock(&mutex);
}
@end


@implementation FFEngine (AudioPlay)
- (void)readNextAudioFrame:(AudioQueueBufferRef)aqBuffer {
    dispatch_async(audio_play_dispatch_queue, ^{
        float audioCacheDuration = [self.audioFrameCacheQueue count] * [self.mediaAudioContext oneFrameDuration];
        pthread_mutex_lock(&(self->mutex));
        BOOL isDecodeComplete = self.isDecodeComplete;
        pthread_mutex_unlock(&(self->mutex));
        if(audioCacheDuration < MIN_AUDIO_FRAME_DURATION && [self.audioFrameCacheQueue count] < MIN_AUDIO_FRAME_COUNT && !isDecodeComplete) {
            NSLog(@"Audio is not enough, wait…");
            NSLog(@"audio1 [_NotifyWaitThreadWakeUp]: %ld", [self.audioFrameCacheQueue count]);
            _NotifyWaitThreadWakeUp(self.decodeCondition);
            _SleepThread(self.audioPlayCondition);
        }
        FFQueueAudioObject *obj = [self.audioFrameCacheQueue dequeue];
        if(audioCacheDuration < MAX_AUDIO_FRAME_DURATION && [self.audioFrameCacheQueue count] < MAX_AUDIO_FRAME_COUNT) {
            NSLog(@"audio2 [_NotifyWaitThreadWakeUp]: %ld", [self.audioFrameCacheQueue count]);
            _NotifyWaitThreadWakeUp(self.decodeCondition);
        }
        if(obj) {
            [self.audioPlayer receiveData:obj.data length:obj.length aqBuffer:aqBuffer pts:obj.pts duration:obj.duration];
        } else {
            if(isDecodeComplete) {
                NSLog(@"Audio frame play completed.");
                [self stopAudioPlay];
            }
        }
    });
}
- (void)updateAudioClock:(float)pts duration:(float)duration {
    pthread_mutex_lock(&mutex);
    self->audio_clock = pts + duration;
    if([self.delegate respondsToSelector:@selector(playCurrentTime:)]) {
        [self.delegate playCurrentTime:self->audio_clock];
    }
    pthread_mutex_unlock(&mutex);
}
@end
