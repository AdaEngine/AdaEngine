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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window.makeKeyAndOrderFront(nil)
        window.title = "Ada Editor"
        window.center()
        
        do {
            let renderer = try RenderEngine.createRenderEngine(backendType: .metal, appName: "Ada")
            let view = MetalView()
            view.isPaused = true
            view.delegate = self
            
            try renderer.initialize(for: view, size: Vector2i(x: 800, y: 600))
            
            window.contentView = view
            
            view.isPaused = false
        } catch {
            fatalError(error.localizedDescription)
        }
        
        
        let scene = Scene()
        
        let entity = Entity()
        let meshRenderer = MeshRenderer()
        
        let train = Bundle.module.url(forResource: "train", withExtension: "obj")!
        let mesh = Mesh.loadMesh(from: train)
        
        meshRenderer.mesh = mesh
        entity.components[MeshRenderer] = meshRenderer
        scene.addEntity(entity)
        
        SceneManager.shared.presentScene(scene)
    }
    
    // MARK: - MTKViewDelegate
    
    func draw(in view: MTKView) {
        GameLoop.current.iterate()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        do {
            try RenderEngine.shared.updateViewSize(newSize: Vector2i(x: Int(size.width), y: Int(size.height)))
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}
#endif
