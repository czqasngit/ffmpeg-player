//
//  FFMediaVideoContext.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/1/4.
//

import Foundation

class FFMediaVideoContext {
    
    private let stream: UnsafeMutablePointer<AVStream>!
    private let formatContext: UnsafeMutablePointer<AVFormatContext>!
    private let fmt: AVPixelFormat
    private var frame = av_frame_alloc()
    private var outputFrame = av_frame_alloc()
    private var filter: FFFilter!
    
    private var codec: UnsafeMutablePointer<AVCodec>!
    private var codecContext: UnsafeMutablePointer<AVCodecContext>!
    deinit {
        if(self.codecContext != nil) {
            avcodec_close(self.codecContext)
            avcodec_free_context(&codecContext)
        }
        av_frame_free(&frame)
        av_frame_free(&outputFrame)
    }
    public init?(stream: UnsafeMutablePointer<AVStream>?,
                 formatContext: UnsafeMutablePointer<AVFormatContext>?,
                 fmt: AVPixelFormat) {
        guard let stream = stream, let formatContext = formatContext else { return nil }
        self.stream = stream
        self.formatContext = formatContext
        self.fmt = fmt
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
        print("FPS: \(av_q2d(self.stream.pointee.avg_frame_rate))");
        print("Duration: \(Int(Double(self.stream.pointee.duration) * av_q2d(self.stream.pointee.time_base))) Seconds");
        print("Size: (\(self.codecContext.pointee.width), \(self.codecContext.pointee.height))");
        print("Decodec: \(String.init(cString: self.codec.pointee.long_name))");
        print("=========================================================");
        
        guard let filter = FFFilter.init(formatContext: formatContext,
                                    codecContext: codecContext,
                                    stream: stream,
                                    fmt: fmt) else {
            return false
        }
        self.filter = filter
        
        return true
    }
}

extension FFMediaVideoContext {
    public var streamIndex: Int { Int(self.stream.pointee.index) }
    public var fps: Double { av_q2d(self.stream.pointee.avg_frame_rate) }
    public func decode(packet: UnsafeMutablePointer<AVPacket>) -> UnsafeMutablePointer<AVFrame>? {
        var ret = avcodec_send_packet(codecContext, packet)
        guard ret == 0 else { return nil }
        av_frame_unref(frame)
        ret = avcodec_receive_frame(codecContext, frame)
        guard ret == 0 else { return nil }
        av_frame_unref(outputFrame)
        guard filter.getTargetFormatFrame(inputFrame: frame!, outputFrame: &(outputFrame!)) else { return nil }
        return outputFrame
    }
}
