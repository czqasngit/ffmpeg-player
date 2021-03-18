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
    private var hwFrame: UnsafeMutablePointer<AVFrame>!
    private var filter: FFFilter!
    
    private var codec: UnsafeMutablePointer<AVCodec>!
    private var codecContext: UnsafeMutablePointer<AVCodecContext>!
    private var hwDeviceContext: UnsafeMutablePointer<AVBufferRef>!
    
    deinit {
        if self.codecContext != nil {
            avcodec_close(self.codecContext)
            avcodec_free_context(&codecContext)
        }
        av_frame_unref(frame)
        av_frame_free(&frame)
        if self.hwFrame != nil {
            av_frame_unref(self.hwFrame)
            av_frame_free(&hwFrame)
        }
    }
    public init?(stream: UnsafeMutablePointer<AVStream>?,
                 formatContext: UnsafeMutablePointer<AVFormatContext>?,
                 fmt: AVPixelFormat,
                 enableHWDecode: Bool) {
        guard let stream = stream, let formatContext = formatContext else { return nil }
        self.stream = stream
        self.formatContext = formatContext
        self.fmt = fmt
        if(!setup(enableHWDeocde: enableHWDecode)) { return nil }
    }
    // MARK: -
    private func setup(enableHWDeocde: Bool) -> Bool {
        guard let codecpar = self.stream.pointee.codecpar else { return false }
        guard let codecPointer = avcodec_find_decoder(codecpar.pointee.codec_id) else { return false }
        self.codec = codecPointer
        guard let codecContextPointer = avcodec_alloc_context3(codecPointer) else { return false }
        self.codecContext = codecContextPointer
        var ret = avcodec_parameters_to_context(self.codecContext, codecpar)
        guard ret >= 0 else { return false }
        if enableHWDeocde {
            var supportVideoToolBoxHWDeocde = false
            var index: Int32 = 0
            while true {
                guard let config = avcodec_get_hw_config(self.codec, index) else {
                    break
                }
                if config.pointee.device_type == AV_HWDEVICE_TYPE_VIDEOTOOLBOX  {
                    supportVideoToolBoxHWDeocde = true
                    break
                }
                index += 1
            }
            if supportVideoToolBoxHWDeocde {
                ret = av_hwdevice_ctx_create(&hwDeviceContext, AV_HWDEVICE_TYPE_VIDEOTOOLBOX, nil, nil, 0)
                guard ret == 0 else { return false }
                codecContext.pointee.hw_device_ctx = hwDeviceContext
                self.hwFrame = av_frame_alloc()
            }
        }
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
    public func oneFrameDuration() -> Double { 1.0 / av_q2d(stream.pointee.avg_frame_rate) }
    public func getStream() -> UnsafeMutablePointer<AVStream> { self.stream }
    public func getDuration() -> Float {
        return Float(self.stream.pointee.duration) * Float(av_q2d(stream.pointee.time_base))
    }
    public func getContext() -> UnsafeMutablePointer<AVCodecContext> { self.codecContext }
    public func decode(packet: UnsafeMutablePointer<AVPacket>,
                       outputFrame: UnsafeMutablePointer<UnsafeMutablePointer<AVFrame>>) -> Bool {
        var ret = avcodec_send_packet(codecContext, packet)
        guard ret == 0 else { return false }
        av_frame_unref(frame)
        if codecContext.pointee.hw_device_ctx != nil {
            av_frame_unref(self.hwFrame)
            ret = avcodec_receive_frame(codecContext, hwFrame)
            guard ret == 0 else { return false }
            ret = av_hwframe_transfer_data(self.frame, self.hwFrame, 0)
            guard ret == 0 else { return false }
        } else {
            ret = avcodec_receive_frame(codecContext, frame)
        }
        guard ret == 0 else { return false }
        if(frame!.pointee.pts == PTS_INVALID) {
            frame!.pointee.pts = self.hwFrame.pointee.pts
        }
        av_frame_unref(outputFrame.pointee)
        guard filter.getTargetFormatFrame(inputFrame: frame!, outputFrame: outputFrame) else { return false }
//        print("读取到视频帧: \(Double(outputFrame!.pointee.pts) * av_q2d(stream.pointee.time_base))")
        return true
    }
}
