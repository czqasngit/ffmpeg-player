//
//  FFEngine.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/1/4.
//

import Foundation

class FFEngine {
    
    private let render: FFVideoRender
    private var formatContext:UnsafeMutablePointer<AVFormatContext>!
    private var videoContext: FFMediaVideoContext!
    private var audioContext: FFMediaAudioContext!
    private var decodeTimer: Timer?
    private let decodeQueue = DispatchQueue.init(label: "decode queue")
    private var packet = av_packet_alloc()
    
    deinit {
        av_packet_unref(packet)
        av_packet_free(&packet)
    }
    init(render: FFVideoRender) {
        self.render = render
    }
    
    private func setupMediaContext(enableHWDecode: Bool) -> Bool {
        let streamCount = formatContext.pointee.nb_streams
        for i in 0..<streamCount {
            let stream = formatContext.pointee.streams.advanced(by: Int(i)).pointee!
            let mediaType = stream.pointee.codecpar.pointee.codec_type
            if mediaType == AVMEDIA_TYPE_VIDEO {
                guard let vc = FFMediaVideoContext.init(stream: stream,
                                                        formatContext: formatContext,
                                                        fmt: self.render.pixFMT,
                                                        enableHWDecode: enableHWDecode) else {
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
        return true
    }
    private func startDecodeTimer() {
        if let timer = self.decodeTimer {
            timer.invalidate()
            self.decodeTimer = nil
        }
        self.decodeTimer = Timer.scheduledTimer(timeInterval: 1.0 / self.videoContext.fps,
                                                target: self,
                                                selector: #selector(displayNext(frame:)),
                                                userInfo: nil,
                                                repeats: true)
    }
    // MARK: -
    public func setup(url: String, enableHWDecode: Bool) -> Bool {
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
        guard setupMediaContext(enableHWDecode: enableHWDecode) else { return false }
        self.startDecodeTimer()
        return true;
    }
}

extension FFEngine {
    @objc private func displayNext(frame: UnsafeMutablePointer<AVFrame>) {
        decodeQueue.async {
            /// only display video use this variable
            var stop = false
            while(!stop) {
                av_packet_unref(self.packet)
                if(av_read_frame(self.formatContext, self.packet) == 0) {
                    if(self.packet!.pointee.stream_index == self.videoContext.streamIndex) {
                        if let frame = self.videoContext.decode(packet: self.packet!) {
                            self.render.display(with: frame)
                            stop = true
                        }
                    }
                }
            }
        }
    }
}
