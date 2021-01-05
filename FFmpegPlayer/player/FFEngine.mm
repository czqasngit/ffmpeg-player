//
//  FFEngine.m
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/4.
//

#import "FFEngine.h"
#import "FFMediaVideoContext.h"
#import "FFMediaAudioContext.h"
#import "FFFilter.h"
#import "FFVideoRender.h"

@interface FFEngine()
@property (nonatomic, strong)FFMediaVideoContext *mediaVideo;
@property (nonatomic, strong)FFMediaAudioContext *mediaAudio;
@property (nonatomic, strong)FFFilter *filter;
@property (nonatomic, strong)id<FFVideoRender> videoRender;
@end
@implementation FFEngine {
    AVFormatContext *formatContext;
}

- (instancetype)initWithVideoRender:(id<FFVideoRender>)videoRender {
    self = [super init];
    if (self) {
        self.videoRender = videoRender;
    }
    return self;
}
- (void)dealloc {
    if(formatContext) {
        avformat_close_input(&formatContext);
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
            _mediaVideo = [[FFMediaVideoContext alloc] initWithAVStream:stream formatContext:formatContext];
            if(!_mediaVideo) goto fail;
        } else if(mediaType == AVMEDIA_TYPE_AUDIO) {
            _mediaAudio = [[FFMediaAudioContext alloc] initWithAVStream:stream formatContext:formatContext];
            if(!_mediaAudio) goto fail;
        }
    }
    self.filter = [[FFFilter alloc] initWithVideoContext:self.mediaVideo
                                           formatContext:formatContext stream:formatContext->streams[self.mediaVideo.streamIndex] outputFmt:[self.videoRender piexlFormat]];
    if(!self.filter) goto fail;
    return YES;
fail:
    if(formatContext) {
        avformat_close_input(&formatContext);
    }
    return NO;
}

@end
