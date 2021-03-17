//
//  FFAudioQueuePlayer.m
//  FFmpegPlayer
//
//  Created by Mark on 2021/1/16.
//

#import "FFAudioQueuePlayer.h"
#import <AudioToolbox/AudioToolbox.h>

#define MAX_BUFFER_COUNT 3

static void _AudioQueueOutputCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
    FFAudioQueuePlayer *player = (__bridge FFAudioQueuePlayer *)inUserData;
    [player reuseAudioQueueBuffer:inBuffer];
}

@interface FFAudioQueuePlayer()
@property (nonatomic, weak)id<FFAudioQueuePlayerDelegate> delegate;
@end
@implementation FFAudioQueuePlayer {
    AudioQueueRef audioQueue;
    FFAudioInformation audioInformation;
    CFMutableArrayRef buffers;
    AVStream *stream;
}

- (void)dealloc {
    
    for(NSInteger i = 0; i < CFArrayGetCount(buffers); i ++) {
        AudioQueueFreeBuffer(self->audioQueue, (AudioQueueBufferRef)CFArrayGetValueAtIndex(buffers, i));
    }
    CFArrayRemoveAllValues(buffers);
    AudioQueueDispose(self->audioQueue, YES);
    
}
- (instancetype)initWithAudioInformation:(FFAudioInformation)audioInformation
                                  stream:(AVStream *)stream
                                delegate:(id<FFAudioQueuePlayerDelegate>)delegate {
    self = [super init];
    if (self) {
        self->audioInformation = audioInformation;
        self->stream = stream;
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
    asbd.mSampleRate = audioInformation.rate;
    /// 音频流格式
    asbd.mFormatID = kAudioFormatLinearPCM;
    /// 每一帧音频格式的通道数
    asbd.mChannelsPerFrame = audioInformation.channels;
    /// 一个pacet有多少个采样帧
    /// 一个采样帧就是一次声道数据采集
    /// PCM这个值是1
    asbd.mFramesPerPacket = 1;
    /// 每个通道一帧占的位宽
    asbd.mBitsPerChannel = audioInformation.bitsPerChannel;
    /// 每一帧所占的字节数
    asbd.mBytesPerFrame = audioInformation.bytesPerSample;
    /// 一个packet所占的字节数
    asbd.mBytesPerPacket = asbd.mFramesPerPacket * asbd.mBytesPerFrame;
    /// kLinearPCMFormatFlagIsSignedInteger: 存储的数据类型
    /// kAudioFormatFlagIsPacked: 数据交叉排列
    asbd.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    asbd.mReserved = 0;
    OSStatus status = AudioQueueNewOutput(&asbd,
                                          _AudioQueueOutputCallback,
                                          (__bridge void *)self,
                                          NULL,
                                          NULL,
                                          0, &audioQueue);
    
    NSAssert(status == errSecSuccess, @"Initialize audioQueue Failed");
    for(NSInteger i = 0; i < MAX_BUFFER_COUNT; i ++) {
        AudioQueueBufferRef audioQueueBuffer = NULL;
        status = AudioQueueAllocateBuffer(self->audioQueue, audioInformation.buffer_size, &audioQueueBuffer);
        NSAssert(status == errSecSuccess, @"Initialize AudioQueueBuffer Failed");
        CFArrayAppendValue(buffers, audioQueueBuffer);
    }
}

#pragma mark - Private
- (void)reuseAudioQueueBuffer:(AudioQueueBufferRef)aqBuffer {
    [self.delegate readNextAudioFrame:aqBuffer];
}

#pragma mark - Public
- (void)receiveData:(uint8_t *)data
             length:(int64_t)length
           aqBuffer:(AudioQueueBufferRef)aqBuffer
                pts:(float)pts
           duration:(float)duration {
    if(!data || !aqBuffer) return;
    aqBuffer->mAudioDataByteSize = (int)length;
    memcpy(aqBuffer->mAudioData, data, length);
    AudioQueueEnqueueBuffer(self->audioQueue, aqBuffer, 0, NULL);
//    NSLog(@"[播放]: %f, 时长: %f", pts, duration);
    [self.delegate updateAudioClock:pts duration:duration];
}
- (void)play {
    AudioQueueStart(audioQueue, NULL);
    NSLog(@"初始投放音频数据");
    for(NSInteger i = 0; i < MAX_BUFFER_COUNT; i ++) {
        AudioQueueBufferRef aqBuffer = (AudioQueueBufferRef)CFArrayGetValueAtIndex(buffers, i);
        [self.delegate readNextAudioFrame:aqBuffer];
    }
}
- (void)stop {
    AudioQueueStop(audioQueue, YES);
}
- (void)pause {
    AudioQueuePause(audioQueue);
    NSLog(@"[音频]暂停");
}
- (void)resume {
    AudioQueueStart(audioQueue, NULL);
    NSLog(@"[音频]恢复");
}
- (void)cleanQueueCacheData {
    AudioQueueFlush(audioQueue);
}
@end
