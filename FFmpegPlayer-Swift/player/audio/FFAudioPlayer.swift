//
//  FFAudioPlayer.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/1/21.
//

import Foundation
import AudioToolbox

class FFAudioPlayerProtocol {
    
}
class FFAudioPlayer {
    private let absd: AudioStreamBasicDescription
    private let delegate: FFAudioPlayerProtocol
    private let audioInformation: FFAudioInformation
    init(_ audioInformation: FFAudioInformation, _ delegate: FFAudioPlayerProtocol) {
        self.audioInformation = audioInformation
        self.absd = .init(mSampleRate: audioInformation.rate,
                          mFormatID: kAudioFormatLinearPCM,
                          mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
                          mBytesPerPacket: UInt32(audioInformation.bytesPerSample),
                          mFramesPerPacket: 1,
                          mBytesPerFrame: UInt32(audioInformation.bytesPerSample),
                          mChannelsPerFrame: UInt32(audioInformation.channels),
                          mBitsPerChannel: UInt32(audioInformation.bitsPerChannel),
                          mReserved: false)
        self.delegate = delegate
    }
    
}
