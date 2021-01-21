//
//  FFVideoPlayer.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/1/21.
//

import Foundation

protocol FFVideoPlayerProtocol {
    func readNextFrame()
}
class FFVideoPlayer {
    private let videoRenderQueue: DispatchQueue
    private let render: FFVideoRender
    private let fps: Double
    private let delegate: FFVideoPlayerProtocol
    private var timer: DispatchSourceTimer?
    
    deinit {
        if let timer = self.timer {
            timer.cancel()
        }
    }
    init(queue videoRenderQueue: DispatchQueue,
         render: FFVideoRender,
         fps: Double,
         delegate: FFVideoPlayerProtocol) {
        self.videoRenderQueue = videoRenderQueue
        self.render = render
        self.fps = fps
        self.delegate = delegate
    }
}

// MARK: - Render
extension FFVideoPlayer {
    public func displayFrame(frame: UnsafeMutablePointer<AVFrame>!) {
        self.render.display(with: frame)
    }
}

// MARK: - Control
extension FFVideoPlayer {

    private func timerHandler() {
        self.delegate.readNextFrame()
    }
    public func startPlay() {
        if let timer = self.timer {
            timer.cancel()
        }
        self.timer = DispatchSource.makeTimerSource(queue: self.videoRenderQueue)
        let duration = DispatchTimeInterval.milliseconds(Int.init(1.0 / (Double)(self.fps) * 1000))
        self.timer?.schedule(deadline: DispatchTime.now(),
                             repeating: duration,
                             leeway: duration)
        self.timer?.setEventHandler(handler: timerHandler)
        self.timer?.resume()
    }
    
    public func stopPlay() {
        if let timer = self.timer {
            timer.cancel()
        }
    }
}
