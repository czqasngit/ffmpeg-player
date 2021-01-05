//
//  FFEngine.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/1/4.
//

import Foundation

class FFEngine {
    private var formatContext:UnsafeMutablePointer<AVFormatContext>!
    private var videoContext: FFMediaVideoContext!
    private var audioContext: FFMediaAudioContext!
    
    public func setup(url: String) -> Bool {
        guard let path = (url as NSString).utf8String else { return false }
        var ret = avformat_open_input(&formatContext, path, nil, nil)
        guard ret == 0 && formatContext != nil else { return false }
        ret = avformat_find_stream_info(formatContext, nil)
        guard ret >= 0 else {
            avformat_close_input(&formatContext)
            return false
        }
        let streamCount = formatContext.pointee.nb_streams
        guard  streamCount > 0 else { return false }
        for i in 0..<streamCount {
            let stream = formatContext.pointee.streams.advanced(by: Int(i)).pointee!
            let mediaType = stream.pointee.codecpar.pointee.codec_type
            if mediaType == AVMEDIA_TYPE_VIDEO {
                guard let vc = FFMediaVideoContext.init(stream: stream, formatContext: formatContext) else {
                    avformat_close_input(&formatContext)
                    return false
                }
                self.videoContext = vc
            } else if mediaType == AVMEDIA_TYPE_AUDIO {
                guard let ac = FFMediaAudioContext.init(stream: stream, formatContext: formatContext) else {
                    avformat_close_input(&formatContext)
                    return false
                }
                self.audioContext = ac
            }
        }
        return true;
    }
}
