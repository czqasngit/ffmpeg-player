//
//  FFAudioQueuePlayer.m
//  FFmpegPlayer
//
//  Created by Mark on 2021/1/16.
//

#import "FFAudioQueuePlayer.h"
#import <AudioToolbox/AudioToolbox.h>
#import "FFQueue.h"

static void _AudioQueueOutputCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
    FFAudioQueuePlayer *player = (__bridge FFAudioQueuePlayer *)inUserData;
    [player reuseAudioQueueBuffer:inBuffer];
}

@interface _AudioQueueBufferObject: NSObject
- (instancetype)init:(AudioQueueBufferRef)audioQueueBuffer;
- (AudioQueueBufferRef)aqBuffer;
@end
@implementation _AudioQueueBufferObject {
    AudioQueueBufferRef audioQueueBuffer;
}
- (instancetype)init:(AudioQueueBufferRef)audioQueueBuffer {
    self = [super init];
    if (self) {
        self->audioQueueBuffer = audioQueueBuffer;
    }
    return self;
}
- (AudioQueueBufferRef)aqBuffer {
    return self->audioQueueBuffer;
}
@end

@interface FFAudioQueuePlayer()
@property (nonatomic, strong)FFQueue *frameQueue;
@property (nonatomic, strong)FFQueue *aqBufferQueue;
@property (nonatomic, strong)NSCondition *condition;
@end
@implementation FFAudioQueuePlayer {
    dispatch_queue_t audioqueue_play_queue;
    AudioQueueRef audioQueue;
    AVCodecContext *audioCodecContext;
    struct SwrContext *au_convert_ctx;
    int buffer_size;
}

- (void)dealloc {
    if(au_convert_ctx) swr_free(&au_convert_ctx);
}
- (instancetype)initWithAudioCodecContext:(AVCodecContext *)audioCodecContext {
    self = [super init];
    if (self) {
        self->audioCodecContext = audioCodecContext;
        self->audioqueue_play_queue = dispatch_queue_create("audio queue play queue", NULL);
        _frameQueue = [[FFQueue alloc] init];
        _aqBufferQueue = [[FFQueue alloc] init];
        [self initializeAudioQueue];
        [self initializeSwr];
    }
    return self;
}
#pragma mark -
- (void)initializeAudioQueue {
    /// 播放器播放时的ffmpeg采样格式
    /// 指定了播放器在读取数据时的数据长度(一帧多少个字节)
    AVSampleFormat sampleFormat = AV_SAMPLE_FMT_S16;
    AudioStreamBasicDescription asbd;
    /// 采样率
    asbd.mSampleRate = audioCodecContext->sample_rate;
    /// 音频流格式
    asbd.mFormatID = kAudioFormatLinearPCM;
    /// 每一帧音频格式的通道数
    asbd.mChannelsPerFrame = 2;//audioCodecContext->channels;
    asbd.mFramesPerPacket = 1;
    /// 每个通道一帧占的位宽
    asbd.mBitsPerChannel = 8 * av_get_bytes_per_sample(sampleFormat);
    /// 每一帧所占的字节数
    asbd.mBytesPerFrame = asbd.mChannelsPerFrame * av_get_bytes_per_sample(sampleFormat);
    asbd.mBytesPerPacket = asbd.mFramesPerPacket * asbd.mBytesPerFrame;
    asbd.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    asbd.mReserved = NO;
    OSStatus status = AudioQueueNewOutput(&asbd,
                                          _AudioQueueOutputCallback,
                                          (__bridge void *)self,
                                          NULL,
                                          NULL,
                                          0, &audioQueue);
    
    NSAssert(status == errSecSuccess, @"Initialize AudioQueue Failed");
    buffer_size = av_samples_get_buffer_size(NULL, 2, audioCodecContext->frame_size, AV_SAMPLE_FMT_S16, 1);
    for(NSInteger i = 0; i < 3; i ++) {
        AudioQueueBufferRef audioQueueBuffer = NULL;
        OSStatus status = AudioQueueAllocateBuffer(self->audioQueue, self->buffer_size, &audioQueueBuffer);
        NSAssert(status == errSecSuccess, @"Initialize AudioQueueBuffer Failed");
        _AudioQueueBufferObject *obj = [[_AudioQueueBufferObject alloc] init:audioQueueBuffer];
        [self.aqBufferQueue enqueue:obj];
    }
}
- (void) initializeSwr {
    /// 重采样成双通道,AV_SAMPLE_FMT_S16数据格式
    au_convert_ctx = swr_alloc_set_opts(NULL,
                                        AV_CH_LAYOUT_STEREO,
                                        AV_SAMPLE_FMT_S16,
                                        audioCodecContext->sample_rate,
                                        audioCodecContext->channel_layout,
                                        audioCodecContext->sample_fmt,
                                        audioCodecContext->sample_rate,
                                        0,
                                        NULL);
    swr_init(au_convert_ctx);
}
#pragma mark - Private
- (void)reuseAudioQueueBuffer:(AudioQueueBufferRef)aqBuffer {
    dispatch_async(audioqueue_play_queue, ^{
        _AudioQueueBufferObject *obj = [[_AudioQueueBufferObject alloc] init:aqBuffer];
        [self.aqBufferQueue enqueue:obj];
        [self playNextFrame];
    });
}
- (void)playNextFrame{
    dispatch_async(audioqueue_play_queue, ^{
        /// 没有可以播放的帧数据
        if(self.frameQueue.count == 0) return;
        /// 没有可用的AudioQueueBuffer
        if(self.aqBufferQueue.count == 0) return;
        NSData *data = [self.frameQueue dequeue];
        NSLog(@"播放frame count: %ld", self.frameQueue.count);
        _AudioQueueBufferObject *obj = (_AudioQueueBufferObject *)[self.aqBufferQueue dequeue];
        if(obj && obj.aqBuffer) {
            obj.aqBuffer->mAudioDataByteSize = self->buffer_size;
            memcpy(obj.aqBuffer->mAudioData, [data bytes], self->buffer_size);
            AudioQueueEnqueueBuffer(self->audioQueue, obj.aqBuffer, 0, NULL);
        }
    });
}
#pragma mark - Public
- (void)receiveFrame:(AVFrame *)frame {
    uint8_t *buffer = (uint8_t *)malloc(buffer_size);
    /// Resample in decode queue
    swr_convert(au_convert_ctx, &buffer, frame->nb_samples, (const uint8_t **)frame->data, frame->nb_samples);
    NSData *data = [[NSData alloc] initWithBytesNoCopy:buffer length:buffer_size];
    dispatch_async(audioqueue_play_queue, ^{
        [self.frameQueue enqueue:data];
        NSLog(@"frame count: %ld", self.frameQueue.count);
        [self playNextFrame];
    });
}
- (void)play {
    AudioQueueStart(audioQueue, NULL);
}
- (void)stop {
    
}
@end
