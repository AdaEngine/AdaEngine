//
//  MacApplication.swift
//  
//
//  Created by v.prusakov on 10/9/21.
//

#if os(macOS)
import Foundation
import AppKit
import QuartzCore

final class MacApplication: Application {
    
    var timer: Timer!
    var displayLink: DisplayLink
    
    override init(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws {
        self.displayLink = DisplayLink(on: .main)!
        try super.init(argc: argc, argv: argv)
        self.windowManager = MacOSWindowManager()
    }
    
    override func run(options: ApplicationRunOptions) throws {
        let app = AdaApplication.shared
        app.setActivationPolicy(.regular)
        app.finishLaunching()
        
        let delegate = MacAppDelegate()
        app.delegate = delegate
        
        app.activate(ignoringOtherApps: true)
        
        self.displayLink.setHandler { [weak self] in
            self?.update()
        }
        
        self.displayLink.start()
        
        app.run()
    }
    
    override func terminate() {
        NSApplication.shared.terminate(nil)
    }
    
    @discardableResult
    override func openURL(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }
    
    @objc private func update() {
        do {
            try self.gameLoop.iterate()
        } catch {
            print(error.localizedDescription)
            exit(-1)
        }
    }
}

class AdaApplication: NSApplication {
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyUp && event.modifierFlags.contains(.command) {
            self.keyWindow?.sendEvent(event)
        } else {
            super.sendEvent(event)
        }
    }
}

class DisplayLink {
    private let timer: CVDisplayLink
    private let source: DispatchSourceUserDataAdd
    
    var isRunning: Bool {
        return CVDisplayLinkIsRunning(timer)
    }
    
    init?(on queue: DispatchQueue = DispatchQueue.main) {
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
    
    func start() {
        guard !self.isRunning else { return }
        
        CVDisplayLinkStart(self.timer)
        self.source.resume()
    }
    
    func pause() {
        guard self.isRunning else { return }
        
        CVDisplayLinkStop(timer)
        self.source.cancel()
    }
    
    func setHandler(_ handler: @escaping () -> Void) {
        self.source.setEventHandler(handler: handler)
    }
    
    deinit {
        if self.isRunning {
            self.pause()
        }
    }
}

#endif
