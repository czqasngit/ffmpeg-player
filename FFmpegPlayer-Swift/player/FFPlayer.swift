//
//  FFPlayer.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/1/4.
//

import Foundation

class FFPlayer {
    private let engine = FFEngine.init()
    
    public func play(url: String) -> Bool {
        guard engine.setup(url: url) else { return false }
        
        return true;
    }
}
