//
//  MacApplication.swift
//  
//
//  Created by v.prusakov on 10/9/21.
//

#if os(macOS)
import Foundation
import AppKit

class MacApplication: Application {
    required init(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws {
        try super.init(argc: argc, argv: argv)
    }
    
    override func run() throws {
        let app = AdaApplication.shared
        app.setActivationPolicy(.regular)
        
        let delegate = MacAppDelegate()
        app.delegate = delegate
        app.activate(ignoringOtherApps: true)
        
        Engine.shared.run()
        
        app.run()
    }
    
    override func terminate() {
        NSApplication.shared.terminate(nil)
    }
    
    @discardableResult
    override func openURL(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
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

#endif
