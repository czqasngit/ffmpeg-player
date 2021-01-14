//
// Created by Mark on 2021/1/15.
//

import Foundation
import AppKit

class FFMetalRender: NSView, FFVideoRender {

    func display(with frame: UnsafeMutablePointer<AVFrame>) {

    }
    var render: NSView { self }
    var pixFMT: AVPixelFormat { AV_PIX_FMT_NV12 }
}