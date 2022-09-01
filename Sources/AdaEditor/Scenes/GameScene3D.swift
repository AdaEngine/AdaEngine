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
        
        let mesh = Mesh.generateBox(extent: [1, 1, 1], segments: [1, 1, 1])
        
        let train = Entity(name: "Train")
        train.components += ModelComponent(mesh: mesh)
        scene.addEntity(train)
        
        return scene
    }
}
