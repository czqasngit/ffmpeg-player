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
    private var frame = av_frame_alloc()
    public var audioInformation: FFAudioInformation!
    private var swrCtx: OpaquePointer!
    
    deinit {
        if(self.codecContext != nil) {
            avcodec_close(self.codecContext)
            avcodec_free_context(&codecContext)
        }
        av_frame_unref(frame)
        av_frame_free(&frame)
    }
    public init?(stream: UnsafeMutablePointer<AVStream>?,
                 formatContext: UnsafeMutablePointer<AVFormatContext>?) {
        guard let stream = stream, let formatContext = formatContext else { return nil }
        self.stream = stream
        self.formatContext = formatContext
        if(!setup()) { return nil }
        setupSwr()
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
        
        let fmt = AV_SAMPLE_FMT_S16
        let channels = 2
        let buffer_size = Int(av_samples_get_buffer_size(nil,
                                                         Int32(channels),
                                                         codecContext.pointee.frame_size,
                                                         fmt,
                                                         1))
        let bitsPerChannel = Int(av_get_bytes_per_sample(fmt)) * 8
        let bytesPerSample = Int(av_get_bytes_per_sample(fmt)) * channels
        self.audioInformation = .init(bufferSize: buffer_size,
                                      format: fmt,
                                      rate: Int(codecContext.pointee.sample_rate),
                                      channels: channels,
                                      bitsPerChannel: bitsPerChannel,
                                      bytesPerSample: bytesPerSample)
        return true
    }
    private func setupSwr() {
        let channel_layout = audioInformation.channels == 1 ? AV_CH_LAYOUT_MONO : AV_CH_LAYOUT_STEREO;
        self.swrCtx = swr_alloc_set_opts(nil,
                                         Int64(channel_layout),
                                         self.audioInformation.format,
                                         Int32(self.audioInformation.rate),
                                         Int64(self.codecContext.pointee.channel_layout),
                                         self.codecContext.pointee.sample_fmt,
                                         Int32(self.codecContext.pointee.sample_rate),
                                         0,
                                         nil)
        swr_init(self.swrCtx)
    }
}

extension FFMediaAudioContext {
    public var streamIndex: Int { return Int(self.stream.pointee.index) }
    public func oneFrameDuration() -> Double {
        let frameSize = Double(codecContext.pointee.frame_size)
        let bytesPerFrame = Double(av_get_bytes_per_sample(codecContext.pointee.sample_fmt))
        let channels = Double(codecContext.pointee.channels)
        let sampleRate = Double(codecContext.pointee.sample_rate)
        return frameSize * bytesPerFrame * channels / sampleRate
    }
    public var timeBase: AVRational { return self.codecContext.pointee.time_base }
}

extension FFMediaAudioContext {
    public func decode(packet: UnsafeMutablePointer<AVPacket>, outBuffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, outBufferSize:UnsafeMutablePointer<UInt32>) -> Bool {
        var ret = avcodec_send_packet(self.codecContext, packet)
        guard ret == 0 else { return false }
        av_frame_unref(frame)
        ret = avcodec_receive_frame(self.codecContext, frame)
        guard ret == 0 else { return false }
        let p = getPointer(frame)
        let size = swr_convert(self.swrCtx, outBuffer, frame!.pointee.nb_samples, p, frame!.pointee.nb_samples)
        outBufferSize.pointee = UInt32(size) * UInt32(self.audioInformation.bytesPerSample)
        av_frame_unref(frame)
        return true
    }
    public func getContext() -> UnsafeMutablePointer<AVCodecContext> { return self.codecContext }
}
