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
        
        camera.transform.matrix = Transform3D(columns: [[0.96498215, -0.043567587, -0.25867215, -0.0], [-6.5283107e-10, 0.9861108, -0.16608849, -0.0], [0.26231548, 0.16027243, 0.95157933, -0.0], [-0.5, -0.4999999, 4.1150093, 0.99999994]])
        
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
    
    private var speed: Float = 50
    
    override func update(_ deltaTime: TimeInterval) {
        
        if Input.isKeyPressed(.arrowDown) {
            camera.transform.position.z += -1
        }
        
        if Input.isKeyPressed(.arrowUp) {
            camera.transform.position.z += 1
        }
        
        
        if Input.isKeyPressed(.w) {
            camera.transform.position += .up * deltaTime * speed
        }
        
        if Input.isKeyPressed(.a) {
            camera.transform.position += .left * deltaTime * speed
        }
        
        if Input.isKeyPressed(.d) {
            camera.transform.position += .right * deltaTime * speed
        }
        
        if Input.isKeyPressed(.s) {
            camera.transform.position += .down * deltaTime * speed
        }
    }
}
