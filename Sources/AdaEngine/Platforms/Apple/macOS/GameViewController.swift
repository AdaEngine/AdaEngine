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
        ViewportComponentSystem.registerSystem()
        
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

final class EditorCamera: Camera {
    
    @Export
    var speed: Float = 20
    
    var cameraUp: Vector3 = Vector3(0, 1, 0)
    var cameraFront: Vector3 = Vector3(0, 0, -1)
    
    var lastMousePosition: Point = .zero
    
    @Export
    var yaw = Angle.radians(-90)
    @Export
    var pitch = Angle.radians(0)
    
    var isViewMatrixDirty = false
    
    override func update(_ deltaTime: TimeInterval) {
        
//        self.mouseEvent()
        
        if Input.isKeyPressed(.w) {
            self.transform.position += speed * cameraFront * deltaTime
            self.isViewMatrixDirty = true
        }
        
        if Input.isKeyPressed(.a) {
            self.transform.position -= cross(cameraFront, cameraUp).normalized * speed * deltaTime
            self.isViewMatrixDirty = true
        }
        
        if Input.isKeyPressed(.d) {
            self.transform.position += cross(cameraFront, cameraUp).normalized * speed * deltaTime
            self.isViewMatrixDirty = true
        }
        
        if Input.isKeyPressed(.s) {
            self.transform.position -= speed * cameraFront * deltaTime
            self.isViewMatrixDirty = true
        }
        
        if self.isViewMatrixDirty {
            self.viewMatrix = Transform3D.lookAt(
                eye: self.transform.position,
                center: self.transform.position + self.cameraFront,
                up: self.cameraUp
            )
            
            self.isViewMatrixDirty = false
        }
    }
    
    func mouseEvent() {
        let position = Input.getMousePosition()
        var xoffset = position.x - self.lastMousePosition.x;
        var yoffset = self.lastMousePosition.y - position.y;
        self.lastMousePosition = position

        let sensitivity: Float = 0.1
        xoffset *= sensitivity
        yoffset *= sensitivity

        self.yaw   += xoffset
        self.pitch += yoffset
        
        if self.pitch.radians > 89.0 {
            self.pitch = 89.0
        } else if(pitch.radians < -89.0) {
            self.pitch = -89.0
        }
        
        var direction = Vector3()
        direction.x = cos(yaw.radians) * cos(pitch.radians)
        direction.y = sin(pitch.radians)
        direction.z = sin(yaw.radians) * cos(pitch.radians)
        
        self.cameraFront = direction.normalized
        self.isViewMatrixDirty = true
    }
}

typealias Point = Vector2
