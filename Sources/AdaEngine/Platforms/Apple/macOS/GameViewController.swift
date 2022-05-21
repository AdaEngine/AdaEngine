//
//  File.swift
//  
//
//  Created by v.prusakov on 11/11/21.
//

#if canImport(AppKit)

import AppKit
import MetalKit
import Yams

final class GameViewController: NSViewController {
    
    var gameView: MetalView {
        return self.view as! MetalView
    }
    
    override func loadView() {
        self.view = MetalView()
    }
    
    // TODO: test
    let gameScene = GameScene()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            let renderer = try RenderEngine.createRenderEngine(backendType: .metal, appName: "Ada")
            gameView.isPaused = true
            gameView.delegate = self
            
            let size = Size(
                width: Float(self.view.frame.size.width),
                height: Float(self.view.frame.size.height)
            )
            
            try renderer.initialize(for: gameView, size: size)
            
            gameView.isPaused = false
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    var scene: Scene?
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        ScriptComponentUpdateSystem.registerSystem()
        CameraSystem.registerSystem()
        
        let scene = gameScene.makeScene()
        Engine.shared.setRootScene(scene)
        self.scene = scene
    }
}

// MARK: - MTKViewDelegate

extension GameViewController: MTKViewDelegate {
    
    func draw(in view: MTKView) {
        GameLoop.current.iterate()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        do {
            let size = Size(width: Float(size.width), height: Float(size.height))
            self.scene?.viewportSize = size
            try RenderEngine.shared.updateViewSize(newSize: size)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}

#endif
