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
app.setActivationPolicy(.regular)

class AppDelegate: NSObject, NSApplicationDelegate {
    let window = NSWindow(contentRect: NSMakeRect(200, 200, 800, 600),
                          styleMask: [.titled, .closable, .resizable, .miniaturizable],
                          backing: .buffered,
                          defer: false,
                          screen: NSScreen.main)
    
    private var renderer: RenderBackend!
    private var triangle: VulkanTriangle!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window.makeKeyAndOrderFront(nil)
        window.title = "Ada Editor"
        window.center()
        
        let view = MetalView()
        view.frame.size = window.frame.size
        view.autoresizingMask = [.height, .width]
        window.contentView?.addSubview(view)
        self.triangle = VulkanTriangle()
        
        NotificationCenter.default.addObserver(self, selector: #selector(resizeWindow(_:)), name: NSWindow.didResizeNotification, object: self.window)
        
        do {
            
//            try self.triangle.run(on: view)
            
            self.renderer = try VulkanRenderBackend(appName: "Ada Engine")
            try renderer.createWindow(for: view, size: Vector2i(x: 800, y: 600))

            self.runMainLoop()
        } catch {
            print(error)
        }
    }
    
    func runMainLoop() {
        let timer = Timer.scheduledTimer(timeInterval: 1 / 60, target: self, selector: #selector(draw), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
    }
    
    @objc func resizeWindow(_ notification: Notification) {
        let window = (notification.object as! NSWindow)
        let newSize = window.frame.size
        do {
            try self.renderer.resizeWindow(newSize: Vector2i(x: Int(newSize.width), y: Int(newSize.height)))
        } catch {
            print(error.localizedDescription)
        }
    }
    
    @objc func draw() {
        do {
//            try self.triangle.drawFrame()
            try self.renderer.beginFrame()
//
//            try self.renderer.endFrame()
        } catch {
            print(error.localizedDescription)
        }
    }
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()

#endif
