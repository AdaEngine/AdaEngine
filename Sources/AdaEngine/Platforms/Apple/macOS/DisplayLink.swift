//
//  DisplayLink.swift
//  
//
//  Created by v.prusakov on 5/31/22.
//

#if MACOS
import AppKit

public final class DisplayLink {
    private let timer: CVDisplayLink
    private let source: DispatchSourceUserDataAdd
    
    public var isRunning: Bool {
        return CVDisplayLinkIsRunning(timer)
    }
    
    public init?(on queue: DispatchQueue = DispatchQueue.main) {
        self.source = DispatchSource.makeUserDataAddSource(queue: queue)
        
        var timerRef: CVDisplayLink?
        
        var successLink = CVDisplayLinkCreateWithActiveCGDisplays(&timerRef)
        
        if let timer = timerRef {
            successLink = CVDisplayLinkSetOutputCallback(timer, { _, _, _, _, _, source -> CVReturn in
                if let source = source {
                    let sourceUnmanaged = Unmanaged<DispatchSourceUserDataAdd>.fromOpaque(source)
                    sourceUnmanaged.takeUnretainedValue().add(data: 1)
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
        self.source.resume()
    }
    
    public func pause() {
        guard self.isRunning else { return }
        
        CVDisplayLinkStop(timer)
        self.source.cancel()
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

#endif
