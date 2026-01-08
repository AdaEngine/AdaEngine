//
//  DisplayLink.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/31/22.
//

#if MACOS
import AppKit
import Logging

/// This class linked with display and call update method each time when display is updated.
public final class DisplayLink: NSObject {
    private var displayLink: CADisplayLink!
    private var source: DisplayLinkEventHandler

    public init(screen: NSScreen) {
        self.source = DisplayLinkEventHandler()
        super.init()

        self.displayLink = screen.displayLink(
            target: self,
            selector: #selector(onDisplayLinkUpdate)
        )
        // Explicitly add to run loop to ensure it works
        self.displayLink.add(to: .current, forMode: .default)
    }
    
    public func start() {
        displayLink.isPaused = false
    }
    
    public func pause() {
        displayLink.isPaused = true
    }
    
    public func setHandler(_ handler: @escaping DisplayLinkHandlerBlock) {
        self.source.setEventHandler(handler: handler)
    }
    
    deinit {
        if !self.displayLink.isPaused {
            self.pause()
        }
    }

    @objc nonisolated private func onDisplayLinkUpdate() {
        source.onEvent()
    }
}

public typealias DisplayLinkHandlerBlock = () -> Void

struct DisplayLinkEventHandler {

    private var handler: DisplayLinkHandlerBlock?

    mutating func setEventHandler(handler: @escaping DisplayLinkHandlerBlock) {
        self.handler = handler
    }

    func onEvent() {
        self.handler?()
    }
}

#endif
