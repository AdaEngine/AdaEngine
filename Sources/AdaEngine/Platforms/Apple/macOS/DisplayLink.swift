//
//  DisplayLink.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/31/22.
//

#if MACOS
import AppKit

/// This class linked with display and call update method each time when display is updated.
public final class DisplayLink: @unchecked Sendable {
    private let timer: CVDisplayLink
    private let source: DisplayLinkEventHandler

    public var isRunning: Bool {
        return CVDisplayLinkIsRunning(timer)
    }
    
    public init?(on queue: DispatchQueue = DispatchQueue.main) {
        self.source = DisplayLinkEventHandler(queue: queue)

        var timerRef: CVDisplayLink?
        
        var successLink = CVDisplayLinkCreateWithActiveCGDisplays(&timerRef)
        
        if let timer = timerRef {
            successLink = CVDisplayLinkSetOutputCallback(timer, { _, _, _, _, _, source -> CVReturn in
                if let source = source {
                    let sourceUnmanaged = Unmanaged<DisplayLinkEventHandler>.fromOpaque(source)
                    sourceUnmanaged.takeUnretainedValue().onEvent()
                }
                
                return kCVReturnSuccess
            }, Unmanaged.passUnretained(self.source).toOpaque())
            
            guard successLink == kCVReturnSuccess else {
                print("Failed to create timer with active display")
                return nil
            }
            
            successLink = CVDisplayLinkSetCurrentCGDisplay(timer, CGMainDisplayID())
            
            guard successLink == kCVReturnSuccess else {
                return nil
            }
            
            self.timer = timer
        } else {
            return nil
        }
    }
    
    public func start() {
        guard !self.isRunning else { return }
        
        CVDisplayLinkStart(self.timer)
    }
    
    public func pause() {
        guard self.isRunning else { return }
        
        CVDisplayLinkStop(timer)
    }
    
    public func setHandler(_ handler: @escaping () -> Void) {
        self.source.setEventHandler(handler: handler)
    }
    
    deinit {
        if self.isRunning {
            self.pause()
        }
    }
}

final class DisplayLinkEventHandler {

    private var handler: (() -> Void)?
    private let queue: DispatchQueue

    init(queue: DispatchQueue) {
        self.queue = queue
    }

    func setEventHandler(handler: @escaping () -> Void) {
        self.handler = handler
    }

    func onEvent() {
        queue.async {
            self.handler?()
        }
    }

}

#endif
