//
//  FFVideoPlayer.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/1/21.
//

import Foundation

protocol FFVideoPlayerProtocol {
    func readNextVideoFrame()
    func updateVideoClock(pts: Double, duration: Double)
}
class FFVideoPlayer {
    private let videoRenderQueue: DispatchQueue
    private let render: FFVideoRender
    private let fps: Double
    private let delegate: FFVideoPlayerProtocol
    private var timer: DispatchSourceTimer?
    private let stream: UnsafeMutablePointer<AVStream>
    
    deinit {
        if let timer = self.timer {
            timer.cancel()
        }
    }
    init(queue videoRenderQueue: DispatchQueue,
         render: FFVideoRender,
         fps: Double,
         stream: UnsafeMutablePointer<AVStream>,
         delegate: FFVideoPlayerProtocol) {
        self.videoRenderQueue = videoRenderQueue
        self.render = render
        self.fps = fps
        self.stream = stream
        self.delegate = delegate
    }
}

// MARK: - Render
extension FFVideoPlayer {
    public func displayFrame(frame: UnsafeMutablePointer<AVFrame>!) {
        let unit = av_q2d(self.stream.pointee.time_base)
        let pts = Double(frame.pointee.pts) * unit
        let duration = Double(frame.pointee.pkt_duration) * unit
        self.render.display(with: frame)
        self.delegate.updateVideoClock(pts: pts, duration: duration)
    }
}

// MARK: - Control
extension FFVideoPlayer {

    private func timerHandler() {
        self.delegate.readNextVideoFrame()
    }
    public func start() {
        if let timer = self.timer {
            timer.cancel()
        }
        self.timer = DispatchSource.makeTimerSource(queue: self.videoRenderQueue)
        let duration = DispatchTimeInterval.nanoseconds(Int.init(1.0 / (Double)(self.fps) * Double(NSEC_PER_SEC)))
        self.timer?.schedule(deadline: DispatchTime.now(), repeating: duration, leeway: duration)
        self.timer?.setEventHandler(handler: timerHandler)
        self.timer?.resume()
    }
    
    public func stop() {
        if let timer = self.timer {
            timer.cancel()
        }
    }
    func pause() {
        self.stop()
    }
    func resume() {
        self.start()
    }
}
