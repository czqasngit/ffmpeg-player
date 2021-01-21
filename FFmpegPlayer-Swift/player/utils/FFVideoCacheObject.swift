//
//  FFVideoCacheObject.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/1/21.
//

import Foundation

class FFVideoCacheObject {
    private var frame: UnsafeMutablePointer<AVFrame>!
    
    deinit {
        av_frame_unref(frame)
        av_frame_free(&frame)
    }
    init() {
        self.frame = av_frame_alloc();
    }
}
extension FFVideoCacheObject {
    public func getFrame() -> UnsafeMutablePointer<AVFrame> { frame }
}
