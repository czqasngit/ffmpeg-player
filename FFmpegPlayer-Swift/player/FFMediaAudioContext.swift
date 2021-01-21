//
//  FFMediaAudioContext.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/1/4.
//

import Foundation

class FFMediaAudioContext {
    
    private let stream: UnsafeMutablePointer<AVStream>!
    private let formatContext: UnsafeMutablePointer<AVFormatContext>!
    private var codec: UnsafeMutablePointer<AVCodec>!
    private var codecContext: UnsafeMutablePointer<AVCodecContext>!
    public var audioInformation: FFAudioInformation!
    
    deinit {
        if(self.codecContext != nil) {
            avcodec_close(self.codecContext)
            avcodec_free_context(&codecContext)
        }
    }
    public init?(stream: UnsafeMutablePointer<AVStream>?,
                 formatContext: UnsafeMutablePointer<AVFormatContext>?) {
        guard let stream = stream, let formatContext = formatContext else { return nil }
        self.stream = stream
        self.formatContext = formatContext
        if(!setup()) { return nil }
    }
    // MARK: -
    private func setup() -> Bool {
        guard let codecpar = self.stream.pointee.codecpar else { return false }
        guard let codecPointer = avcodec_find_decoder(codecpar.pointee.codec_id) else { return false }
        self.codec = codecPointer
        guard let codecContextPointer = avcodec_alloc_context3(codecPointer) else { return false }
        self.codecContext = codecContextPointer
        var ret = avcodec_parameters_to_context(self.codecContext, codecpar)
        guard ret >= 0 else { return false }
        ret = avcodec_open2(self.codecContext, self.codec, nil)
        guard ret == 0 else { return false }
        print("=================== Video Information ===================");
        print("Sample Rate: \(codecContext.pointee.sample_rate)");
        print("FMT: \(codecContext.pointee.sample_fmt), \(String.init(cString: av_get_sample_fmt_name(codecContext.pointee.sample_fmt)))");
        print("Channels: \(codecContext.pointee.channels)");
        print("Channel Layout: \(codecContext.pointee.channel_layout)");
        print("Decodec: \(String.init(cString: codec.pointee.long_name))");
        print("=========================================================");
        
        return true
    }
}

extension FFMediaAudioContext {
    public var streamIndex: Int { return Int(self.stream.pointee.index) }
    public func onFrameDuration() -> Double {
        let frameSize = Double(codecContext.pointee.frame_size)
        let bytesPerFrame = Double(av_get_bytes_per_sample(codecContext.pointee.sample_fmt))
        let channels = Double(codecContext.pointee.channels)
        let sampleRate = Double(codecContext.pointee.sample_rate)
        return frameSize * bytesPerFrame * channels / sampleRate
    }
}
