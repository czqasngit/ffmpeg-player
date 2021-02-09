//
//  FFVideoCacheObject.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/1/21.
//

import Foundation

class FFVideoCacheObject {
    private var frame: UnsafeMutablePointer<AVFrame>!
    private var pts: Double
    private let duration: Double
    deinit {
        av_frame_unref(frame)
        av_frame_free(&frame)
    }
    init(pts: Double, duration: Double) {
        self.frame = av_frame_alloc();
        self.pts = pts
        self.duration = duration
    }
}
extension FFVideoCacheObject {
    public func getFrame() -> UnsafeMutablePointer<AVFrame> { frame }
    public func getPTS() -> Double { self.pts }
    public func setPTS(_ pts: Double) { self.pts = pts }
    public func getDuration() -> Double { self.duration }
}
