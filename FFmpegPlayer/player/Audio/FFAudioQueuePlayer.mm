//
//  FFAudioQueuePlayer.m
//  FFmpegPlayer
//
//  Created by Mark on 2021/1/16.
//

#import "FFAudioQueuePlayer.h"
#import <AudioToolbox/AudioToolbox.h>

static void _AudioQueueOutputCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
    FFAudioQueuePlayer *player = (__bridge FFAudioQueuePlayer *)inUserData;
    [player reuseAudioQueueBuffer:inBuffer];
}


@interface FFAudioQueuePlayer()
@property (nonatomic, weak)id<FFAudioQueuePlayerDelegate> delegate;
@end
@implementation FFAudioQueuePlayer {
    AudioQueueRef audioQueue;
    int buffer_size;
    AVSampleFormat sampleFormat;
    int sampleRate;
    CFMutableArrayRef buffers;
}

- (void)dealloc {
    
    for(NSInteger i = 0; i < CFArrayGetCount(buffers); i ++) {
        AudioQueueFreeBuffer(self->audioQueue, (AudioQueueBufferRef)CFArrayGetValueAtIndex(buffers, i));
    }
    CFArrayRemoveAllValues(buffers);
    AudioQueueDispose(self->audioQueue, YES);
    
}
- (instancetype)initWithBufferSize:(int)bufferSize
                      sampleFormat:(AVSampleFormat)sampleFormat
                        sampleRate:(int)sampleRate
                          delegate:(id<FFAudioQueuePlayerDelegate>)delegate {
    self = [super init];
    if (self) {
        self->buffer_size = bufferSize;
        self->sampleFormat = sampleFormat;
        self->sampleRate = sampleRate;
        self.delegate = delegate;
        self->buffers = CFArrayCreateMutable(CFAllocatorGetDefault(), 0, NULL) ;
        [self initializeAudioQueue];
    }
    return self;
}
#pragma mark -
- (void)initializeAudioQueue {
    /// 播放器播放时的ffmpeg采样格式
    /// 指定了播放器在读取数据时的数据长度(一帧多少个字节)
    AudioStreamBasicDescription asbd;
    /// 采样率
    asbd.mSampleRate = sampleRate;
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
    for(NSInteger i = 0; i < 3; i ++) {
        AudioQueueBufferRef audioQueueBuffer = NULL;
        status = AudioQueueAllocateBuffer(self->audioQueue, buffer_size, &audioQueueBuffer);
        NSAssert(status == errSecSuccess, @"Initialize AudioQueueBuffer Failed");
        CFArrayAppendValue(buffers, audioQueueBuffer);
    }
}

#pragma mark - Private
- (void)reuseAudioQueueBuffer:(AudioQueueBufferRef)aqBuffer {
    [self.delegate readNextAudioFrame:aqBuffer];
}

#pragma mark - Public
- (void)receiveData:(uint8_t *)data length:(int)length aqBuffer:(AudioQueueBufferRef)aqBuffer {
    if(!data || !aqBuffer) return;
    aqBuffer->mAudioDataByteSize = length;
    memcpy(aqBuffer->mAudioData, data, length);
    AudioQueueEnqueueBuffer(self->audioQueue, aqBuffer, 0, NULL);
}
- (void)play {
    AudioQueueStart(audioQueue, NULL);
    NSLog(@"初始投放音频数据");
    for(NSInteger i = 0; i < 3; i ++) {
        AudioQueueBufferRef aqBuffer = (AudioQueueBufferRef)CFArrayGetValueAtIndex(buffers, i);
        [self.delegate readNextAudioFrame:aqBuffer];
    }
}
- (void)stop {
    
}

#pragma mark - Public

@end
