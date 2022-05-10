//
//  MacAppDelegate.swift
//  
//
//  Created by v.prusakov on 10/9/21.
//

#if os(macOS)
import Vulkan
import CVulkan
import CSDL2
import Foundation
import AppKit
import MetalKit

class MacAppDelegate: NSObject, NSApplicationDelegate {
    
    let window = NSWindow(
        contentRect: NSMakeRect(200, 200, 800, 600),
        styleMask: [.titled, .closable, .resizable, .miniaturizable],
        backing: .buffered,
        defer: false,
        screen: NSScreen.main
    )
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window.makeKeyAndOrderFront(nil)
        window.title = "Ada Editor"
        window.center()
        
        let viewController = GameViewController(nibName: nil, bundle: nil)
        window.contentViewController = viewController
        
        window.setFrame(NSMakeRect(200, 200, 800, 600), display: true)
    }
}
#endif
