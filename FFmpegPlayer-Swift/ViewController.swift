//
//  ViewController.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/1/4.
//

import Cocoa

class ViewController: NSViewController {
    
    private let player = FFPlayer.init()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let url = Bundle.main.path(forResource: "1280x720", ofType: "mp4") {
            _ = self.player.play(url: url)
        }
    }


}

