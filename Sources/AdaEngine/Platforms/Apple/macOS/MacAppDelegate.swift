//
//  MacAppDelegate.swift
//  
//
//  Created by v.prusakov on 10/9/21.
//

#if os(macOS)
import Foundation
import AppKit
import MetalKit

class MacAppDelegate: NSObject, NSApplicationDelegate {
    
    var window: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        let contentRect = NSRect(x: 200, y: 200, width: 800, height: 800)
        
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false,
            screen: NSScreen.main
        )
        
        window.makeKeyAndOrderFront(nil)
        window.title = "Ada Editor"
        window.center()
        
        let viewController = MacOSGameViewController(nibName: nil, bundle: nil)
        window.contentViewController = viewController
        
        window.setFrame(contentRect, display: true)
        
        self.window = window
    }
}
#endif
