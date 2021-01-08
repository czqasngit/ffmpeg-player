//
//  FFFilter.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/1/6.
//

import Foundation

class FFFilter {
    
    private let formatContext: UnsafeMutablePointer<AVFormatContext>
    private let codecContext: UnsafeMutablePointer<AVCodecContext>
    private let stream: UnsafeMutablePointer<AVStream>!
    private let fmt: AVPixelFormat
    private var graph: UnsafeMutablePointer<AVFilterGraph>!
    private var bufferContext: UnsafeMutablePointer<AVFilterContext>!
    private var bufferSinkContext: UnsafeMutablePointer<AVFilterContext>!
    
    deinit {
        avfilter_graph_free(&graph)
        if(self.bufferContext != nil) {
            avfilter_free(bufferContext)
        }
        if(self.bufferSinkContext != nil) {
            avfilter_free(bufferSinkContext)
        }
    }
    public init?(formatContext: UnsafeMutablePointer<AVFormatContext>,
                 codecContext: UnsafeMutablePointer<AVCodecContext>,
                 stream: UnsafeMutablePointer<AVStream>,
                 fmt: AVPixelFormat) {
        self.formatContext = formatContext
        self.codecContext = codecContext
        self.stream = stream
        self.fmt = fmt;
        self.graph = avfilter_graph_alloc()
    }
    
    private func setup(format: AVPixelFormat) -> Bool {
        var inputs = avfilter_inout_alloc()
        var outputs = avfilter_inout_alloc()
        defer {
            avfilter_inout_free(&inputs)
            avfilter_inout_free(&outputs)
        }
        let buffer = avfilter_get_by_name("buffer")
        let args = UnsafeMutablePointer<Int8>.allocate(capacity: 512)
        let time_base = stream.pointee.time_base
        /// create buffer filter necessary parameter
        _ = snprintf(ptr: args, 512, "video_size=%dx%d:pix_fmt=%d:time_base=%d/%d:pixel_aspect=%d/%d",
                 codecContext.pointee.width,
                 codecContext.pointee.height,
                 format.rawValue,
                 time_base.num,
                 time_base.den,
                 codecContext.pointee.sample_aspect_ratio.num,
                 codecContext.pointee.sample_aspect_ratio.den)
        var ret = avfilter_graph_create_filter(&bufferContext, buffer, "in", args, nil, graph)
        guard ret >= 0 && bufferContext != nil else { return false }
        let bufferSink = avfilter_get_by_name("buffersink")
        ret = avfilter_graph_create_filter(&bufferSinkContext, bufferSink, "out", nil, nil, graph)
        guard ret >= 0 && bufferSinkContext != nil else { return false }
        let fmts = [self.fmt]
        /// 获取指向fmts连续存储内存的首地址
        /// 指针类型转换成UInt8
        let p = fmts.withUnsafeBufferPointer {
            $0.baseAddress?.withMemoryRebound(to: UInt8.self, capacity: 1) { $0 }
        }
        ret = av_opt_set_bin(bufferSinkContext, "pix_fmts", p, Int32(MemoryLayout<AVPixelFormat>.size), AV_OPT_SEARCH_CHILDREN)
        guard ret >= 0 else { return false }
        
        inputs!.pointee.name = av_strdup("out")
        inputs!.pointee.filter_ctx = bufferSinkContext
        inputs!.pointee.pad_idx = 0
        inputs!.pointee.next = nil
        
        outputs!.pointee.name = av_strdup("in")
        outputs!.pointee.filter_ctx = bufferContext
        outputs!.pointee.pad_idx = 0
        outputs!.pointee.next = nil

        ret = avfilter_graph_parse_ptr(graph, "null", &inputs, &outputs, nil);
        guard ret >= 0 else { return false }
        ret = avfilter_graph_config(graph, nil);
        guard ret >= 0 else { return false }
        return true;
    }
}

extension FFFilter {
    public func getTargetFormatFrame(inputFrame: UnsafeMutablePointer<AVFrame>,
                                     outputFrame:UnsafeMutablePointer<UnsafeMutablePointer<AVFrame>>) -> Bool {
        if bufferContext == nil {
            guard setup(format: AVPixelFormat(rawValue: inputFrame.pointee.format)) else {
                return false
            }
        }
        var ret = av_buffersrc_add_frame(bufferContext, inputFrame)
        guard ret == 0 else { return false }
        ret = av_buffersink_get_frame(bufferSinkContext, outputFrame.pointee)
        guard ret == 0 else { return false }
        return true
    }
}
