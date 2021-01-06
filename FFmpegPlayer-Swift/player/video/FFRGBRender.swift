//
//  FFRGBRender.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/1/6.
//

import Foundation
import AppKit

class FFRGBRender: NSView {
    
    private let rgbImageView = NSImageView.init()
    private let rgbQueue = DispatchQueue.init(label: "rgb generator queue")
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupImageView()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private func setupImageView() {
        rgbImageView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(rgbImageView)
        NSLayoutConstraint.activate([
            self.rgbImageView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.rgbImageView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.rgbImageView.topAnchor.constraint(equalTo: self.topAnchor),
            self.rgbImageView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
        ])
    }
}

extension FFRGBRender : FFVideoRender {
    var pixFMT: AVPixelFormat { return AV_PIX_FMT_RGB24 }
    var render: NSView { self }
    func display(with frame: UnsafeMutablePointer<AVFrame>) {
        print("decode frame: \(frame.pointee.pts)")
        let linesize = frame.pointee.linesize.0
        let height = frame.pointee.height
        let width = frame.pointee.width
        /// frame->data[0] byte size
        let byteSize = Int(linesize * height)
        let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: byteSize)
        memcpy(bytes, frame.pointee.data.0, byteSize)
        rgbQueue.async {
            defer {
                bytes.deallocate()
            }
            guard let data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, bytes, byteSize, kCFAllocatorNull),
                  CFDataGetLength(data) > 0
            else {
                return
            }
            guard let provider = CGDataProvider.init(data: data) else { return }
            let bitmapInfo = CGBitmapInfo.init(rawValue: 0)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let cgImage = CGImage(width: Int(width),
                                        height: Int(height),
                                        bitsPerComponent: 8,
                                        bitsPerPixel: 3 * 8,
                                        bytesPerRow: Int(linesize),
                                        space: colorSpace,
                                        bitmapInfo: bitmapInfo,
                                        provider: provider,
                                        decode: nil,
                                        shouldInterpolate: true,
                                        intent: CGColorRenderingIntent.defaultIntent) else { return }
            let image = NSImage.init(cgImage: cgImage,
                                     size: NSSize.init(width: Int(width),
                                                       height: Int(height)))
            DispatchQueue.main.async {
                self.rgbImageView.image = image
            }
        }
    }
}
