//
//  GameScene3D.swift
//  AdaEditor
//
//  Created by v.prusakov on 8/11/22.
//

import AdaEngine

class GameScene3D {
    func makeScene() async throws -> Scene {
        let scene = Scene(name: "3D")
        
        scene.addSystem(EditorCameraSystem.self)
        
        let camera = EditorCameraEntity()
        camera.components[Camera.self]?.isPrimal = true
        scene.addEntity(camera)
        
        return scene
    }
}
