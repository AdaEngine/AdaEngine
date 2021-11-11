//
//  File.swift
//  
//
//  Created by v.prusakov on 11/11/21.
//

#if canImport(AppKit)

import AppKit
import MetalKit

final class GameViewController: NSViewController {
    
    var gameView: MetalView {
        return self.view as! MetalView
    }
    
    override func loadView() {
        self.view = MetalView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            let renderer = try RenderEngine.createRenderEngine(backendType: .metal, appName: "Ada")
            gameView.isPaused = true
            gameView.delegate = self
            
            try renderer.initialize(for: gameView, size: Vector2i(x: 800, y: 600))
            
            gameView.isPaused = false
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        self.setupScene()
    }
    
    private func setupScene() {
        let scene = Scene()
        
        let trainEntity = Entity()
        let meshRenderer = MeshRenderer()
        
        let train = Bundle.module.url(forResource: "train", withExtension: "obj")!
        let mesh = Mesh.loadMesh(from: train)
        
        meshRenderer.mesh = mesh
        trainEntity.components[MeshRenderer] = meshRenderer
        scene.addEntity(trainEntity)
        
        let userEntity = Entity(name: "user")
        userEntity.components[UserTestComponent] = UserTestComponent()
        
        let camera = CameraComponent()
        camera.makeCurrent()
        userEntity.components[CameraComponent] = camera
        
        scene.addEntity(userEntity)
        
        SceneManager.shared.presentScene(scene)

    }
    
    
}

// MARK: - MTKViewDelegate

extension GameViewController: MTKViewDelegate {
    
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

class UserTestComponent: Component {
    
    @RequiredComponent var camera: CameraComponent
    
    var speed: Float = 50
    
    override func update(_ deltaTime: TimeInterval) {
        if Input.isKeyPressed(.w) {
            camera.transform.position += .up * deltaTime
        }
        
        if Input.isKeyPressed(.a) {
            camera.transform.position += .left * deltaTime
        }
        
        if Input.isKeyPressed(.d) {
            camera.transform.position += .down * deltaTime
        }
        
        if Input.isKeyPressed(.s) {
            camera.transform.position += .right * deltaTime
        }
    }
}
