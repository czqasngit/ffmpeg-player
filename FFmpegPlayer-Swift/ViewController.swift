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
        if let url = Bundle.main.path(forResource: "flutter", ofType: "mp4") {
            _ = self.player.play(url: url, enableHWDecode: true)
        }
        self.view.addSubview(self.player.displayRender)
        self.player.displayRender.frame = .init(x: 0, y: 0, width: 1280, height: 720)
    }


}

