//
//  File.swift
//  
//
//  Created by v.prusakov on 8/10/21.
//

import AdaEngine
import Vulkan
import CVulkan
import CSDL2
import Math

#if os(macOS)

import AppKit
import MetalKit

let app = NSApplication.shared

class AppDelegate: NSObject, NSApplicationDelegate {
    let window = NSWindow(contentRect: NSMakeRect(200, 200, 800, 600),
                          styleMask: [.titled, .closable, .resizable],
                          backing: .buffered,
                          defer: false,
                          screen: NSScreen.main)
    
    private var renderer: RenderBackend!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window.makeKeyAndOrderFront(nil)
        window.title = "Ada Editor"
        let view = MetalView()
        view.frame.size = window.frame.size
        window.contentView?.addSubview(view)
        
        do {
            self.renderer = try VulkanRenderBackend(appName: "Ada Engine")
            try renderer.createWindow(for: view, size: Vector2i(x: 800, y: 600))
        } catch {
            print(error)
        }
    }
    
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()

#endif
