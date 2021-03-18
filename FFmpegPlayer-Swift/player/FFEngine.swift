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

enum FFPlayState {
    case none
    case loading
    case playing
    case pause
    case stop
}
protocol FFEngineProtocol {
    func playerReadyToPlay(_ duration: Float)
    func playerCurrentTime(_ currentTime: Float)
    func playerStateChanged(_ state: FFPlayState)
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
    private var videoClock: Double = 0
    private var audioClock: Double = 0
    private var toleranceScope: Double = 0
    var playState = FFPlayState.none {
        didSet {
            self.ffEngineDelegate?.playerStateChanged(self.playState)
        }
    }
    private var packet = av_packet_alloc()
    var ffEngineDelegate: FFEngineProtocol? = nil
    deinit {
        av_packet_unref(packet)
        av_packet_free(&packet)
    }
    init(render: FFVideoRender) {
        self.render = render
    }
    
    private func setupMediaContext(enableHWDecode: Bool) -> Bool {
        self.playState = .none
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
                                                      stream: stream,
                                                      delegate: self)
                self.toleranceScope = vc.oneFrameDuration()
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
        self.playState = .loading
        self.videoClock = 0
        self.audioClock = 0
    }
    func stop() {
        self.videoPlayer?.stop()
        self.audioPlayer?.stop()
    }
    func pause() {
        self.videoPlayer?.pause()
        self.audioPlayer?.pause()
        self.playState = .pause
    }
    func resume() {
        self.videoPlayer?.resume()
        self.audioPlayer?.resume()
        self.playState = .playing
    }
    func seekTo(_ time: Float) {
        self.pause()
        self.audioCacheQueue.clean()
        self.videoCacheQueue.clean()
        pthread_mutex_lock(&(self.mutex))
        avcodec_flush_buffers(self.videoContext?.getContext())
        avcodec_flush_buffers(self.audioContext?.getContext())
        self.audioPlayer?.cleanCacheData()
        av_seek_frame(self.formatContext, -1, Int64(time * Float(AV_TIME_BASE)), AVSEEK_FLAG_BACKWARD)
        _Wakeup(cond: self.decodeCondition)
        pthread_mutex_unlock(&(self.mutex))
        self.resume()
    }
}
//MARK: - Utility
extension FFEngine {
    func hasEnoughAudio() -> Bool {
        guard let audioContext = self.audioContext else { return false }
        return Double(self.audioCacheQueue.count()) * audioContext.oneFrameDuration() >= MAX_AUDIO_CACHE_DURATION
    }
    func audioCanKeepMoving() -> Bool {
        guard let audioContext = self.audioContext else { return false }
        return Double(self.audioCacheQueue.count()) * audioContext.oneFrameDuration() >= MIN_AUDIO_CACHE_DURATION
    }
    func audioRequireWait() -> Bool {
        guard let audioContext = self.audioContext else { return false }
        return Double(self.audioCacheQueue.count()) * audioContext.oneFrameDuration() < MIN_AUDIO_CACHE_DURATION
    }
    func hasEnoughVideo() -> Bool {
        guard let videoContext = self.videoContext else { return false }
        return Double(self.videoCacheQueue.count()) * videoContext.oneFrameDuration() >= MAX_VIDEO_CACHE_DURATION
    }
    func videoCanKeepMoving() -> Bool {
        guard let videoContext = self.videoContext else { return false }
        return Double(self.videoCacheQueue.count()) * videoContext.oneFrameDuration() >= MIN_VIDEO_CACHE_DURATION
    }
    func videoRequireWait() -> Bool {
        guard let videoContext = self.videoContext else { return false }
        return Double(self.videoCacheQueue.count()) * videoContext.oneFrameDuration() < MIN_VIDEO_CACHE_DURATION
    }
}
// MARK: - Decode
extension FFEngine {
    private func decode() {
        decodeQueue.async {
            while(true) {
                print("[Cache] audio: \(self.audioCacheQueue.count()), video: \(self.videoCacheQueue.count()), \(self.hasEnoughVideo()), \(self.hasEnoughAudio())")
                if self.hasEnoughAudio() && self.hasEnoughVideo() {
                    if self.playState == .loading {
                        self.playState = .playing
                        self.audioPlayer?.play()
                        self.videoPlayer?.start()
                        self.ffEngineDelegate?.playerReadyToPlay(self.videoContext?.getDuration() ?? 0)
                    }
                    _Sleep(cond: self.decodeCondition)
                }
                av_packet_unref(self.packet)
                pthread_mutex_lock(&(self.mutex))
                let ret = av_read_frame(self.formatContext, self.packet)
                pthread_mutex_unlock(&(self.mutex))
                if ret == 0 {
                    if let videoContext = self.videoContext,
                       self.packet!.pointee.stream_index == videoContext.streamIndex {
                        let unit = av_q2d(videoContext.getStream().pointee.time_base)
                        let obj = FFVideoCacheObject.init(pts: 0, duration: videoContext.oneFrameDuration())
                        var frame = obj.getFrame()
                        pthread_mutex_lock(&(self.mutex))
                        let ret = self.videoContext?.decode(packet: self.packet!, outputFrame: &frame) ?? false
                        pthread_mutex_unlock(&(self.mutex))
                        if ret {
                            obj.setPTS(unit * Double(frame.pointee.pts))
                            self.videoCacheQueue.enqueue(obj)
                            if self.videoCanKeepMoving() {
                                _Wakeup(cond: self.videoCondition)
                            }
                        }
                        
                    } else if let audioContext = self.audioContext,
                              self.packet!.pointee.stream_index == audioContext.streamIndex {
                        if let avctx = self.audioContext {
                            let unit = av_q2d(self.audioContext!.timeBase)
                            let pts = unit * Double(self.packet!.pointee.pts)
                            let duration = unit * Double(self.packet!.pointee.duration)
                            let obj = FFAudioCacheObject.init(length: UInt32(avctx.audioInformation.bufferSize),
                                                              pts: pts,
                                                              duration: duration )
                            var outBufferSize: UInt32 = 0
                            var outBuffer: UnsafeMutablePointer<UInt8>! = obj.getCacheData()
                            pthread_mutex_lock(&(self.mutex))
                            let ret = avctx.decode(packet: self.packet!, outBuffer: &outBuffer, outBufferSize: &outBufferSize)
                            pthread_mutex_unlock(&(self.mutex))
                            if ret {
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
    private func readNextVideoFrameByAudioSync() -> FFVideoCacheObject? {
        var ac: Double = 0
        pthread_mutex_lock(&(self.mutex));
        ac = self.audioClock
        pthread_mutex_unlock(&(self.mutex));
        guard var obj = self.videoCacheQueue.dequeue() else { return nil }
        var readCount = 1
        var vc = obj.getPTS() + obj.getDuration()
        print("[Sync] AC: \(ac), VC: \(vc), 误差: \(abs(ac - vc)), 允许误差: \(self.toleranceScope)")
        if(ac - vc > self.toleranceScope) {
            while ac - vc > self.toleranceScope {
                if let nextObj = self.videoCacheQueue.dequeue() {
                    obj = nextObj
                    vc = obj.getPTS() + obj.getDuration()
                    readCount += 1
                } else {
                    break
                }
            }
            print("[Sync]音频太快, 视频追赶 跳过 \(readCount - 1) 帧")
        } else if(vc - ac > self.toleranceScope) {
            let sleepTime = vc - ac
            print("[Sync]视频太快, 等待: \(useconds_t(sleepTime * 1000 * 1000))")
            usleep(useconds_t(sleepTime * 1000 * 1000))
        } else {
            print("[Sync]音视频时钟误差在允许范围内: \(ac), \(vc)")
        }
        return obj
    }
    func readNextVideoFrame() {
        self.videoRenderQueue.async {
            pthread_mutex_lock(&(self.mutex))
            let _decodecComplete = self.decodeCompleted
            pthread_mutex_unlock(&(self.mutex))
            if self.videoRequireWait() && !_decodecComplete {
                _Wakeup(cond: self.decodeCondition)
                _Sleep(cond: self.videoCondition)
            }
            
            if let obj = self.readNextVideoFrameByAudioSync() {
                self.videoPlayer?.displayFrame(frame: obj.getFrame())
                if !self.hasEnoughVideo() {
                    _Wakeup(cond: self.decodeCondition)
                }
            } else {
                if _decodecComplete {
                    print("Video frame render completed.")
                    self.videoPlayer?.stop()
                }
            }
        }
    }
    func updateVideoClock(pts: Double, duration: Double) {
        pthread_mutex_lock(&(self.mutex));
        self.videoClock = pts + duration;
        print("[时钟]视频时钟: \(self.videoClock)")
        pthread_mutex_unlock(&(self.mutex));
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
                self.audioPlayer?.receive(data: obj.getCacheData(),
                                          length: obj.getCacheLength(),
                                          aqBuffer: aqBuffer,
                                          pts: obj.getPTS(),
                                          duration: obj.getDuration())
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
    func updateAudioClock(pts: Double, duration: Double) {
        pthread_mutex_lock(&(self.mutex));
        self.audioClock = pts + duration;
        self.ffEngineDelegate?.playerCurrentTime(Float(self.audioClock))
        pthread_mutex_unlock(&(self.mutex));
    }
}
