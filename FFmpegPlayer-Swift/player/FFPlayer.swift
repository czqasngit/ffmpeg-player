//
//  FFPlayer.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/1/4.
//

import Foundation
import AppKit

class FFPlayer {
    
    private let render = FFMetalRender.init(frame: .zero)
    private let engine: FFEngine
    
    init() {
        self.engine = FFEngine.init(render: render)
    }
    public func play(url: String, enableHWDecode: Bool) -> Bool {
        guard engine.setup(url: url, enableHWDecode: enableHWDecode) else { return false }

        return true;
    }
}

extension FFPlayer {
    var displayRender: NSView { render.render }
}
