//
//  FFVideoRender.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/1/6.
//

import Foundation
import AppKit

protocol FFVideoRender {
    var pixFMT: AVPixelFormat { get }
    var render: NSView { get }
    func display(with frame: UnsafeMutablePointer<AVFrame>)
}
