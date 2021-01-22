//
//  FFEngine.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/1/4.
//

import Foundation
import AudioToolbox

private let MIN_AUDIO_CACHE_DURATION: Double  = 1
private let MAX_AUDIO_CACHE_DURATION: Double = 2
private let MIN_VIDEO_CACHE_DURATION: Double  = 1
private let MAX_VIDEO_CACHE_DURATION: Double  = 2

private func _Wakeup(cond: NSCondition) {
    DispatchQueue.main.async {
        cond.signal()
    }
}
private func _Sleep(cond: NSCondition) {
    cond.wait()
}

class FFEngine {
    
    private let render: FFVideoRender
    private var videoPlayer: FFVideoPlayer?
    private var audioPlayer: FFAudioPlayer?
    private var formatContext:UnsafeMutablePointer<AVFormatContext>!
    private var videoContext: FFMediaVideoContext?
    private var audioContext: FFMediaAudioContext?
    private let videoCacheQueue = FFCacheQueue<FFVideoCacheObject>.init()
    private let audioCacheQueue = FFCacheQueue<FFAudioCacheObject>.init()
    private let decodeQueue = DispatchQueue.init(label: "decode queue")
    private let audioPlayQueue = DispatchQueue.init(label: "audio play queue")
    private let videoRenderQueue = DispatchQueue.init(label: "video render queue")
    private let decodeCondition = NSCondition.init()
    private let audioCondition = NSCondition.init()
    private let videoCondition = NSCondition.init()
    private var mutex = pthread_mutex_t.init()
    private var decodeCompleted = false
    
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
                self.videoPlayer = FFVideoPlayer.init(queue: self.videoRenderQueue,
                                                      render: self.render,
                                                      fps: vc.fps,
                                                      delegate: self)
            } else if mediaType == AVMEDIA_TYPE_AUDIO {
                guard let ac = FFMediaAudioContext.init(stream: stream, formatContext: formatContext) else {
                    avformat_close_input(&formatContext)
                    return false
                }
                self.audioContext = ac
                self.audioPlayer = .init(ac.audioInformation, self)
            }
        }
        return true
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
        self.start()
        return true;
    }
}
extension FFEngine {
    func start() {
        self.decode()
        self.videoPlayer?.startPlay()
        self.audioPlayer?.play()
    }
    func stop() {
        self.videoPlayer?.stopPlay()
        self.audioPlayer?.stop()
    }
}
//MARK: - Utility
extension FFEngine {
    func hasEnoughAudio() -> Bool {
        guard let audioContext = self.audioContext else { return false }
        return Double(self.audioCacheQueue.count()) * audioContext.onFrameDuration() >= MAX_AUDIO_CACHE_DURATION
    }
    func audioCanKeepMoving() -> Bool {
        guard let audioContext = self.audioContext else { return false }
        return Double(self.audioCacheQueue.count()) * audioContext.onFrameDuration() >= MIN_AUDIO_CACHE_DURATION
    }
    func audioRequireWait() -> Bool {
        guard let audioContext = self.audioContext else { return false }
        return Double(self.audioCacheQueue.count()) * audioContext.onFrameDuration() < MIN_AUDIO_CACHE_DURATION
    }
    func hasEnoughVideo() -> Bool {
        guard let videoContext = self.videoContext else { return false }
        return Double(self.videoCacheQueue.count()) * videoContext.onFrameDuration() >= MAX_VIDEO_CACHE_DURATION
    }
    func videoCanKeepMoving() -> Bool {
        guard let videoContext = self.videoContext else { return false }
        return Double(self.videoCacheQueue.count()) * videoContext.onFrameDuration() >= MIN_VIDEO_CACHE_DURATION
    }
    func videoRequireWait() -> Bool {
        guard let videoContext = self.videoContext else { return false }
        return Double(self.videoCacheQueue.count()) * videoContext.onFrameDuration() < MIN_VIDEO_CACHE_DURATION
    }
}
// MARK: - Decode
extension FFEngine {
    private func decode() {
        decodeQueue.async {
            while(true) {
                print("[Cache] audio: \(self.audioCacheQueue.count()), video: \(self.videoCacheQueue.count()), \(self.hasEnoughVideo()), \(self.hasEnoughAudio())")
                if self.hasEnoughAudio() && self.hasEnoughVideo() {
                    _Sleep(cond: self.decodeCondition)
                }
                av_packet_unref(self.packet)
                let ret = av_read_frame(self.formatContext, self.packet)
                if ret == 0 {
                    if let videoContext = self.videoContext,
                       self.packet!.pointee.stream_index == videoContext.streamIndex {
                        let obj = FFVideoCacheObject.init()
                        var frame = obj.getFrame()
                        if let videoContext = self.videoContext,
                           videoContext.decode(packet: self.packet!, outputFrame: &frame) {
                            self.videoCacheQueue.enqueue(obj)
                            if self.videoCanKeepMoving() {
                                _Wakeup(cond: self.videoCondition)
                            }
                        }
                    } else if let audioContext = self.audioContext,
                              self.packet!.pointee.stream_index == audioContext.streamIndex {
                        if let avctx = self.audioContext {
                            let obj = FFAudioCacheObject.init(length: UInt32(avctx.audioInformation.bufferSize))
                            var outBufferSize: UInt32 = 0
                            var outBuffer: UnsafeMutablePointer<UInt8>! = obj.getCacheData()
                            if avctx.decode(packet: self.packet!, outBuffer: &outBuffer, outBufferSize: &outBufferSize) {
                                obj.setCacheLength(outBufferSize)
                                self.audioCacheQueue.enqueue(obj)
                                if self.audioCanKeepMoving() {
                                    _Wakeup(cond: self.audioCondition)
                                }
                            }
                        }
                    }
                } else {
                    if ret == READ_END_OF_FILE {
                        pthread_mutex_lock(&(self.mutex))
                        self.decodeCompleted = true
                        pthread_mutex_unlock(&(self.mutex))
                        break
                    }
                }
            }
            print("Decode complete")
        }
    }
}
// MARK: - FFVideoPlayerProtocol
extension FFEngine : FFVideoPlayerProtocol {
    func readNextVideoFrame() {
        self.videoRenderQueue.async {
            pthread_mutex_lock(&(self.mutex))
            let _decodecComplete = self.decodeCompleted
            pthread_mutex_unlock(&(self.mutex))
            if self.videoRequireWait() && !_decodecComplete {
                _Wakeup(cond: self.decodeCondition)
                _Sleep(cond: self.videoCondition)
            }
            if let obj = self.videoCacheQueue.dequeue() {
                self.videoPlayer?.displayFrame(frame: obj.getFrame())
                if !self.hasEnoughVideo() {
                    _Wakeup(cond: self.decodeCondition)
                }
            } else {
                if _decodecComplete {
                    print("Video frame render completed.")
                    self.videoPlayer?.stopPlay()
                }
            }
        }
    }
}
//MARK : - FFAudioPlayerProtocol
extension FFEngine : FFAudioPlayerProtocol {
    func readNextAudioFrame(_ aqBuffer: AudioQueueBufferRef) {
        print("[AudioPlayer]readNextAudioFrame")
        self.audioPlayQueue.async {
            pthread_mutex_lock(&(self.mutex))
            let _decodecComplete = self.decodeCompleted
            pthread_mutex_unlock(&(self.mutex))
            if self.audioRequireWait() && !_decodecComplete {
                _Wakeup(cond: self.decodeCondition)
                _Sleep(cond: self.audioCondition)
            }
            if let obj = self.audioCacheQueue.dequeue() {
                print("[AudioPlayer]dequeue")
                self.audioPlayer?.receive(data: obj.getCacheData(), length: obj.getCacheLength(), aqBuffer: aqBuffer)
                if !self.hasEnoughAudio() {
                    _Wakeup(cond: self.decodeCondition)
                }
            } else {
                if _decodecComplete {
                    print("Audio frame play completed.")
                    self.audioPlayer?.stop()
                }
            }
        }
    }
}
