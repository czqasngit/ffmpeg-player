//
// Created by Mark on 2021/1/15.
//

import Foundation
import AppKit
import MetalKit
import CoreVideo

class FFMetalRender: MTKView, FFVideoRender {

    private var commandQueue: MTLCommandQueue! = nil
    private var computePipline: MTLComputePipelineState! = nil
    private var pixelBufferPool: CVPixelBufferPool? = nil
    private var metalRenderQueue: DispatchQueue = .init(label: "Metal Render Queue")
    private var metalTextureCache: CVMetalTextureCache? = nil

    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        guard setupMetal() else { fatalError() }
    }

    required init(coder: NSCoder) {
        fatalError()
    }
    private func setupCVPixelBufferIfNeed(_ frame: UnsafeMutablePointer<AVFrame>) {
        guard pixelBufferPool == nil else { return }
        var pixelBufferAttributes: [String: Any] = [:]
        if frame.pointee.color_range == AVCOL_RANGE_MPEG {
            pixelBufferAttributes[kCVPixelBufferPixelFormatTypeKey as String] = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        } else {
            pixelBufferAttributes[kCVPixelBufferPixelFormatTypeKey as String] = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        }
        pixelBufferAttributes[kCVPixelBufferMetalCompatibilityKey as String] = true
        pixelBufferAttributes[kCVPixelBufferWidthKey as String] = frame.pointee.width
        pixelBufferAttributes[kCVPixelBufferHeightKey as String] = frame.pointee.height
        pixelBufferAttributes[kCVPixelBufferBytesPerRowAlignmentKey as String] = frame.pointee.linesize.0
        let ret = CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, pixelBufferAttributes as CFDictionary, &pixelBufferPool)
        guard ret == kCVReturnSuccess else {
            fatalError("initialize CVPixelBufferPool failed")
        }
    }
    /// MARK: - Private
    private func setupMetal() -> Bool {
        guard let device = MTLCreateSystemDefaultDevice() else { return false }
        guard let cmdQueue = device.makeCommandQueue() else { return false }
        self.commandQueue = cmdQueue
        guard let library = device.makeDefaultLibrary() else { return false }
        guard let function = library.makeFunction(name: "yuv420ToRGB") else { return false }
        guard let _computePipline = try? device.makeComputePipelineState(function: function) else { return false }
        self.computePipline = _computePipline
        let ret = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &metalTextureCache)
        guard ret == kCVReturnSuccess else { return false }
        self.device = device
        self.autoResizeDrawable = false
        self.framebufferOnly = false
        return true
    }
    private func makeCVPixelBuffer(from frame: UnsafeMutablePointer<AVFrame>) -> CVPixelBuffer? {
        guard let pixelBufferPool = self.pixelBufferPool else { return nil }
        var pixelBuffer: CVPixelBuffer! = nil
        let ret = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pixelBuffer)
        guard ret == kCVReturnSuccess else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.init(rawValue: 0))
        let ySizePerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let uvSizePerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
        let yBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
        let uvBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)
        memcpy(yBaseAddress, frame.pointee.data.0, ySizePerRow * Int(frame.pointee.height))
        memcpy(uvBaseAddress, frame.pointee.data.1, uvSizePerRow * Int(frame.pointee.height) / 2)
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.init(rawValue: 0))
        return pixelBuffer
    }
    /// MARK: - VideoRender
    func display(with frame: UnsafeMutablePointer<AVFrame>) {
        setupCVPixelBufferIfNeed(frame)
        guard let pixelBuffer = makeCVPixelBuffer(from: frame),
              let metalTextureCache = metalTextureCache else { return }
        
        metalRenderQueue.async {
            let yWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
            let yHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
            var yMetalTexture: CVMetalTexture! = nil
            var ret = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                metalTextureCache,
                                                                pixelBuffer,
                                                                nil,
                                                                MTLPixelFormat.r8Unorm,//MTLPixelFormatR8Unorm,
                                                                yWidth,
                                                                yHeight,
                                                                0,
                                                                &yMetalTexture)
            guard ret == kCVReturnSuccess else { return }
            guard let yTexture = CVMetalTextureGetTexture(yMetalTexture) else { return }
            let uvWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1)
            let uvHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)
            var uvMetalTexture: CVMetalTexture! = nil
            ret = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                            metalTextureCache,
                                                            pixelBuffer,
                                                            nil,
                                                            MTLPixelFormat.rg8Unorm,
                                                            uvWidth,
                                                            uvHeight,
                                                            1,
                                                            &uvMetalTexture)
            guard ret == kCVReturnSuccess else { return }
            guard let uvTexture = CVMetalTextureGetTexture(uvMetalTexture) else { return }
            DispatchQueue.main.async {
                guard let layer = self.layer as? CAMetalLayer else { return }
                guard let drawable = layer.nextDrawable() else { return }
                guard let commandBuffer = self.commandQueue.makeCommandBuffer() else { return }
                guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
                commandEncoder.setComputePipelineState(self.computePipline)
                commandEncoder.setTexture(yTexture, index: 0)
                commandEncoder.setTexture(uvTexture, index: 1)
                var byteSize = simd_make_uint2(UInt32(yWidth), UInt32(yHeight))
                commandEncoder.setBytes(&byteSize, length: MemoryLayout<simd_uint2>.size, index: 2)
                commandEncoder.setTexture(drawable.texture, index: 3)
                let threadExecutionWidth = self.computePipline.threadExecutionWidth
                let maxTotalThreadsPerThreadgroup = self.computePipline.maxTotalThreadsPerThreadgroup
                let threadgroupPerGrid = MTLSize.init(width: threadExecutionWidth,
                                                   height: maxTotalThreadsPerThreadgroup / threadExecutionWidth,
                                                   depth: 1)
                let threadsPerThreadgroup = MTLSize.init(width: (yWidth + threadgroupPerGrid.width - 1) / threadgroupPerGrid.width,
                                                    height: (yHeight + threadgroupPerGrid.height - 1) / threadgroupPerGrid.height,
                                                    depth: 1)
                commandEncoder.dispatchThreadgroups(threadsPerThreadgroup, threadsPerThreadgroup: threadgroupPerGrid)
                commandEncoder.endEncoding()
                commandBuffer.addScheduledHandler { _ in
                    yMetalTexture = nil
                    uvMetalTexture = nil
                }
                commandBuffer.present(drawable)
                commandBuffer.commit()
                
            }
        }
    }
    var render: NSView { self }
    var pixFMT: AVPixelFormat { AV_PIX_FMT_NV12 }
}
