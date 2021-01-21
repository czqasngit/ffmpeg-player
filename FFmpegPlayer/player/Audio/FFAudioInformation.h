//
//  FFAudioInformation.h
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/19.
//

#ifndef FFAudioInformation_h
#define FFAudioInformation_h
extern "C" {
#include <libavformat/avformat.h>
}
/// 播放器参数
struct FFAudioInformation {
    /// 解码后一个完整的数据包字节数
    int buffer_size;
    /// 采样数据格式
    AVSampleFormat format;
    /// 采样率
    int rate;
    /// 通道
    int channels;
    /// 一个采样每个通道占的位宽
    int bitsPerChannel;
    /// 一个采样的字节数
    int bytesPerSample;
};

#endif /* FFAudioInformation_h */
