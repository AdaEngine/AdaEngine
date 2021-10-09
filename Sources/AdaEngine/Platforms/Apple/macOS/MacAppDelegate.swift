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
import Math
import Foundation
import AppKit
import MetalKit

class MacAppDelegate: NSObject, NSApplicationDelegate, MTKViewDelegate {
    
    let window = NSWindow(contentRect: NSMakeRect(200, 200, 800, 600),
                          styleMask: [.titled, .closable, .resizable, .miniaturizable],
                          backing: .buffered,
                          defer: false,
                          screen: NSScreen.main)
    
    private var renderer: RenderBackend!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window.makeKeyAndOrderFront(nil)
        window.title = "Ada Editor"
        window.center()
        
        let view = MetalView()
        view.isPaused = true
        view.delegate = self
        window.contentView = view
        
        do {
            self.renderer = try VulkanRenderBackend(appName: "Ada Engine")
            try renderer.createWindow(for: view, size: Vector2i(x: 800, y: 600))
            
            view.isPaused = false
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    // MARK: - MTKViewDelegate
    
    func draw(in view: MTKView) {
        do {
            Engine.shared.calculateDeltaTime()
            
            try self.renderer.beginFrame()
            
            try self.renderer.endFrame()
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        do {
            try self.renderer?.resizeWindow(newSize: Vector2i(x: Int(size.width), y: Int(size.height)))
        } catch {
            fatalError(error.localizedDescription)
        }
        
    }
}
#endif
