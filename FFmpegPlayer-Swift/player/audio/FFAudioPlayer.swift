//
//  FFAudioPlayer.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/1/21.
//

import Foundation
import AudioToolbox

protocol FFAudioPlayerProtocol {
    func readNextAudioFrame(_ aqBuffer: AudioQueueBufferRef)
}
func audioQueueCallBack(inUserData: UnsafeMutableRawPointer?, audioQueue: AudioQueueRef, aqBuffer: AudioQueueBufferRef) {
    guard let inUserData = inUserData else { return }
    let this = inUserData.bindMemory(to: FFAudioPlayer.self, capacity: 1).pointee
    this.reuseAQBuffer(aqBuffer)
}
class FFAudioPlayer {
    private var absd: AudioStreamBasicDescription
    private let delegate: FFAudioPlayerProtocol
    private let audioInformation: FFAudioInformation
    private var audioQueue: AudioQueueRef?
    private var buffers: CFMutableArray!
    
    deinit {
        if let audioQueue = self.audioQueue {
            AudioQueueDispose(audioQueue, true)
        }
    }
    init(_ audioInformation: FFAudioInformation, _ delegate: FFAudioPlayerProtocol) {
        self.audioInformation = audioInformation
        self.absd = AudioStreamBasicDescription.init(mSampleRate: Float64(audioInformation.rate),
                                                     mFormatID: kAudioFormatLinearPCM,
                                                     mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
                                                     mBytesPerPacket: UInt32(audioInformation.bytesPerSample),
                                                     mFramesPerPacket: 1,
                                                     mBytesPerFrame: UInt32(audioInformation.bytesPerSample),
                                                     mChannelsPerFrame: UInt32(audioInformation.channels),
                                                     mBitsPerChannel: UInt32(audioInformation.bitsPerChannel),
                                                     mReserved: 0)
        self.delegate = delegate
    }
    //MARK: -
    private func setupAudioQueue() -> Bool {
        var this = self
        let ret = AudioQueueNewOutput(&(self.absd), audioQueueCallBack, &this, nil, nil, 0, &audioQueue)
        guard ret == errSecSuccess else { return false }
        self.buffers = CFArrayCreateMutable(kCFAllocatorDefault, 3, nil)
        (0...2).forEach {
            _ in
            var aqBuffer: AudioQueueBufferRef? = nil
            let status = AudioQueueAllocateBuffer(self.audioQueue!, UInt32(self.audioInformation.bufferSize), &aqBuffer)
            if status == errSecSuccess {
                CFArrayAppendValue(self.buffers, aqBuffer)
            }
        }
        return true
    }
}
extension FFAudioPlayer {
    public func reuseAQBuffer(_ aqBuffer: AudioQueueBufferRef) {
        self.delegate.readNextAudioFrame(aqBuffer)
    }
}
extension FFAudioPlayer {
    public func play() {
        guard let audioQueue = self.audioQueue else { return }
        AudioQueueStart(audioQueue, nil)
        (0...(CFArrayGetCount(self.buffers))).forEach {
            let aqBuffer = CFArrayGetValueAtIndex(self.buffers, $0).load(as: AudioQueueBufferRef.self)
            self.delegate.readNextAudioFrame(aqBuffer)
        }
    }
    public func stop() {
        guard let audioQueue = self.audioQueue else { return }
        AudioQueueStop(audioQueue, true)
    }
}
extension FFAudioPlayer {
    public func receive(data: UnsafeMutablePointer<UInt8>, length: UInt32, aqBuffer: AudioQueueBufferRef) {
        guard let audioQueue = self.audioQueue else { return }
        aqBuffer.pointee.mAudioDataByteSize = length
        memcpy(aqBuffer.pointee.mAudioData, data, Int(length))
        AudioQueueEnqueueBuffer(audioQueue, aqBuffer, 0, nil)
    }
}
