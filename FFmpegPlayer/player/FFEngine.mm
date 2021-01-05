//
//  FFEngine.m
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/4.
//

#import "FFEngine.h"
#import "FFMediaVideoContext.h"
#import "FFMediaAudioContext.h"

@interface FFEngine()
@property (nonatomic, strong)FFMediaVideoContext *mediaVideo;
@property (nonatomic, strong)FFMediaAudioContext *mediaAudio;
@end
@implementation FFEngine {
    AVFormatContext *formatContext;
}

- (void)dealloc {
    if(formatContext) {
        avformat_close_input(&formatContext);
    }
}
- (BOOL)setup:(const char *)url {
    int ret = avformat_open_input(&formatContext, url, NULL, NULL);
    if(ret != 0) goto fail;
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
    return YES;
fail:
    if(formatContext) {
        avformat_close_input(&formatContext);
    }
    return NO;
}

@end
