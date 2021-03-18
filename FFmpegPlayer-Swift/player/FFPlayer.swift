//
//  FFPlayer.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/1/4.
//

import Foundation
import AppKit

protocol FFPlayerProtocol {
    func playerReadyToPlay(_ duration: Float)
    func playerCurrentTime(_ currentTime: Float)
    func playerStateChanged(_ state: FFPlayState)
}
class FFPlayer {
    
    private let render = FFMetalRender.init(frame: .zero)
    private let engine: FFEngine
    var ffPlayerDelegate: FFPlayerProtocol? = nil
    init() {
        self.engine = FFEngine.init(render: render)
        self.engine.ffEngineDelegate = self
    }
    public func play(url: String, enableHWDecode: Bool) -> Bool {
        guard engine.setup(url: url, enableHWDecode: enableHWDecode) else { return false }

        return true;
    }
}
extension FFPlayer {
    func pause() {
        self.engine.pause()
    }
    func resume() {
        self.engine.resume()
    }
    func seekTo(_ time: Float) {
        self.engine.seekTo(time)
    }
    func playState() -> FFPlayState { self.engine.playState }
}

extension FFPlayer {
    var displayRender: NSView { render.render }
}
extension FFPlayer: FFEngineProtocol {
    func playerReadyToPlay(_ duration: Float) {
        self.ffPlayerDelegate?.playerReadyToPlay(duration)
    }
    func playerCurrentTime(_ currentTime: Float) {
        self.ffPlayerDelegate?.playerCurrentTime(currentTime)
    }
    func playerStateChanged(_ state: FFPlayState) {
        self.ffPlayerDelegate?.playerStateChanged(state)
    }
}
