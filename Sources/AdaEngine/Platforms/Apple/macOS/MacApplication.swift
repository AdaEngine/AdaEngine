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
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        
        let delegate = MacAppDelegate()
        app.delegate = delegate
        
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

#endif
