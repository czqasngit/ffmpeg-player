//
//  ViewController.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/1/4.
//

import Cocoa

class ViewController: NSViewController {
    
    private let player = FFPlayer.init()
    private let toolBar = ToolBarView.init()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let url = Bundle.main.path(forResource: "1280x720", ofType: "mp4") {
            _ = self.player.play(url: url, enableHWDecode: true)
        }
        self.view.addSubview(self.player.displayRender)
        self.player.displayRender.frame = .init(x: 0, y: 0, width: 1280, height: 720)
        
        self.view.addSubview(toolBar)
        self.toolBar.frame = self.player.displayRender.frame;
        self.toolBar.delegate = self
        self.player.ffPlayerDelegate = self.toolBar
    }
}
extension ViewController: ToolBarViewProtocol {
    func seekTo(_ time: Float) {
        self.player.seekTo(time)
    }
    func togglePlayAction() {
        if self.player.playState() == .pause {
            self.player.resume()
        } else if self.player.playState() == .playing {
            self.player.pause()
        }
    }
    func pause() {
        self.player.pause()
    }
}

