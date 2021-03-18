//
//  ToolBarView.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/3/18.
//

import Cocoa

typealias _NSSliderMouseDownBlock = () -> ()
fileprivate class _NSSlider: NSSlider {
    fileprivate var mouseDownBlock: _NSSliderMouseDownBlock? = nil
    override func mouseDown(with event: NSEvent) {
        if let block = self.mouseDownBlock {
            block()
        }
        super.mouseDown(with: event)
    }
}

protocol ToolBarViewProtocol {
    func seekTo(_ time: Float)
    func togglePlayAction()
    func pause()
}

class ToolBarView: NSView {
    lazy private var container = NSView.init()
    lazy private var durationLabel = NSTextField.init()
    lazy private var currentTimeLabel = NSTextField.init()
    lazy private var slider = _NSSlider.init()
    lazy private var playButton = NSButton.init()
    lazy private var nextButton = NSButton.init()
    lazy private var prevButton = NSButton.init()
    private var duration: Float = 0
    private var currentTime: Float = 0
    var delegate: ToolBarViewProtocol? = nil
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        _setup()
        _layout()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func _setup() {
        self.container.wantsLayer = true
        self.container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        self.container.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.container)
        
        self.slider.wantsLayer = true
        self.slider.translatesAutoresizingMaskIntoConstraints = false
        self.slider.isContinuous = false
        self.slider.target = self
        self.slider.action = #selector(sliderAction(_:))
        self.slider.mouseDownBlock = {[weak self] in
            guard let self = self else { return }
            self.delegate?.pause()
        }
        self.container.addSubview(self.slider)
        
        self.durationLabel.wantsLayer = true
        self.durationLabel.translatesAutoresizingMaskIntoConstraints = false
        self.durationLabel.layer?.backgroundColor = NSColor.clear.cgColor
        self.durationLabel.backgroundColor = NSColor.clear
        self.durationLabel.textColor = NSColor.white
        self.durationLabel.alignment = .center
        self.durationLabel.isEditable = false
        self.durationLabel.isBezeled = false
        self.durationLabel.isBordered = false
        self.durationLabel.font = .systemFont(ofSize: 16)
        self.durationLabel.stringValue = "00:00"
        self.container.addSubview(self.durationLabel)
        
        self.currentTimeLabel.wantsLayer = true
        self.currentTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        self.currentTimeLabel.layer?.backgroundColor = NSColor.clear.cgColor
        self.currentTimeLabel.backgroundColor = NSColor.clear
        self.currentTimeLabel.textColor = NSColor.white
        self.currentTimeLabel.alignment = .center
        self.currentTimeLabel.isEditable = false
        self.currentTimeLabel.isBezeled = false
        self.currentTimeLabel.isBordered = false
        self.currentTimeLabel.font = .systemFont(ofSize: 16)
        self.currentTimeLabel.stringValue = "00:00"
        self.container.addSubview(self.currentTimeLabel)
        
        self.playButton.wantsLayer = true
        self.playButton.translatesAutoresizingMaskIntoConstraints = false
        self.playButton.imageScaling = .scaleAxesIndependently
        self.playButton.image = NSImage.init(named: "play")
        self.playButton.bezelStyle = .texturedSquare
        self.playButton.target = self
        self.playButton.action = #selector(play(_:))
        self.container.addSubview(self.playButton);
        
        self.nextButton.wantsLayer = true
        self.nextButton.translatesAutoresizingMaskIntoConstraints = false
        self.nextButton.imageScaling = .scaleAxesIndependently
        self.nextButton.image = NSImage.init(named: "next")
        self.nextButton.bezelStyle = .texturedSquare
        self.nextButton.target = self
        self.nextButton.action = #selector(speed(_:))
        self.container.addSubview(self.nextButton)
        
        self.prevButton.wantsLayer = true
        self.prevButton.translatesAutoresizingMaskIntoConstraints = false
        self.prevButton.imageScaling = .scaleAxesIndependently
        self.prevButton.image = NSImage.init(named: "prev")
        self.prevButton.bezelStyle = .texturedSquare
        self.prevButton.target = self
        self.prevButton.action = #selector(fastBackward(_:))
        self.container.addSubview(self.prevButton)
        
    }
    private func _layout() {
        self.container.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        self.container.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        self.container.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        self.container.heightAnchor.constraint(equalToConstant: 120.0).isActive = true
        
        self.slider.leadingAnchor.constraint(equalTo: self.container.leadingAnchor, constant: 70.0).isActive = true
        self.slider.trailingAnchor.constraint(equalTo: self.container.trailingAnchor, constant: -70.0).isActive = true
        self.slider.topAnchor.constraint(equalTo: self.container.topAnchor, constant: 30.0).isActive = true
        
        self.durationLabel.centerYAnchor.constraint(equalTo: self.slider.centerYAnchor).isActive = true
        self.durationLabel.trailingAnchor.constraint(equalTo: self.container.trailingAnchor, constant: -10.0).isActive = true
        
        self.currentTimeLabel.centerYAnchor.constraint(equalTo: self.slider.centerYAnchor).isActive = true
        self.currentTimeLabel.leadingAnchor.constraint(equalTo: self.container.leadingAnchor, constant: 10.0).isActive = true
        
        self.playButton.centerXAnchor.constraint(equalTo: self.container.centerXAnchor).isActive = true
        self.playButton.bottomAnchor.constraint(equalTo: self.container.bottomAnchor, constant: -20.0).isActive = true
        self.playButton.widthAnchor.constraint(equalToConstant: 40.0).isActive = true
        self.playButton.heightAnchor.constraint(equalToConstant: 40.0).isActive = true
        
        self.prevButton.trailingAnchor.constraint(equalTo: self.playButton.leadingAnchor, constant: -15.0).isActive = true
        self.prevButton.centerYAnchor.constraint(equalTo: self.playButton.centerYAnchor).isActive = true
        self.prevButton.widthAnchor.constraint(equalToConstant: 40.0).isActive = true
        self.prevButton.heightAnchor.constraint(equalToConstant: 40.0).isActive = true
        
        self.nextButton.leadingAnchor.constraint(equalTo: self.playButton.trailingAnchor, constant: 15.0).isActive = true
        self.nextButton.centerYAnchor.constraint(equalTo: self.playButton.centerYAnchor).isActive = true
        self.nextButton.widthAnchor.constraint(equalToConstant: 40.0).isActive = true
        self.nextButton.heightAnchor.constraint(equalToConstant: 40.0).isActive = true
        
    }
    
    @objc private func play(_ sender: NSButton) {
        self.delegate?.togglePlayAction()
    }
    @objc private func speed(_ sender: NSButton) {
        self.delegate?.seekTo(self.currentTime + 3)
    }
    @objc private func fastBackward(_ sender: NSButton) {
        self.delegate?.seekTo(self.currentTime - 3)
    }
    @objc private func sliderAction(_ sender: _NSSlider) {
        self.delegate?.seekTo(sender.floatValue)
    }
}

extension ToolBarView: FFPlayerProtocol {
    func playerReadyToPlay(_ duration: Float) {
        self.duration = duration;
        DispatchQueue.main.async {
            self.durationLabel.stringValue = String.init(format: "%02d:%02d", Int(duration / 60), Int(duration) % 60);
            self.slider.maxValue = Double(duration)
            self.slider.minValue = 0
        }
    }
    func playerCurrentTime(_ currentTime: Float) {
        self.currentTime = currentTime;
        DispatchQueue.main.async {
            self.currentTimeLabel.stringValue = String.init(format: "%02d:%02d", Int(currentTime / 60), Int(currentTime) % 60)
            self.slider.floatValue = currentTime
        }
    }
    func playerStateChanged(_ state: FFPlayState) {
        DispatchQueue.main.async {
            switch state {
            case .playing:
                self.playButton.image = NSImage.init(named: "pause")
            case .pause:
                self.playButton.image = NSImage.init(named: "play")
            default: break
            }
        }
    }
}
