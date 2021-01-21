//
//  FFAudioCacheObject.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/1/21.
//

import Foundation

class FFAudioCacheObject {
    private var length: UInt32
    private let data: UnsafeMutablePointer<UInt8>
    
    deinit {
        self.data.deallocate()
    }
    init(length: UInt32) {
        self.data = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(length))
        self.length = length
    }
}
extension FFAudioCacheObject {
    public func getCacheData() -> UnsafeMutablePointer<UInt8> { self.data }
    public func getCacheLength() -> UInt32 { self.length }
    public func setCacheLength(_ length: UInt32) { self.length = length }
}
