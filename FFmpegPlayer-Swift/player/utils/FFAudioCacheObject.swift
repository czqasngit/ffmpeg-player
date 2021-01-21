//
//  FFAudioCacheObject.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/1/21.
//

import Foundation

class FFAudioCacheObject {
    private var length: Int
    private let data: UnsafeMutablePointer<UInt8>
    
    deinit {
        self.data.deallocate()
    }
    init(length: Int) {
        self.data = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
        self.length = length
    }
}
extension FFAudioCacheObject {
    public func getCacheData() -> UnsafeMutablePointer<UInt8> { self.data }
    public func getCacheLength() -> Int { self.length }
    public func setCacheLength(_ length: Int) { self.length = length }
}
