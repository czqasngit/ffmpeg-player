//
//  FFAudioInformation.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/1/21.
//

import Foundation

/// 播放器参数
struct FFAudioInformation {
    /// 解码后一个完整的数据包字节数
    var bufferSize: Int
    /// 采样数据格式
    var format: AVSampleFormat
    /// 采样率
    var rate: Int
    /// 通道
    var channels: Int
    /// 一个采样每个通道占的位宽
    var bitsPerChannel: Int
    /// 一个采样的字节数
    var bytesPerSample: Int
};
