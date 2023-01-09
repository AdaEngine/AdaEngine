//
//  GameScene3D.swift
//  AdaEditor
//
//  Created by v.prusakov on 8/11/22.
//

import AdaEngine

class GameScene3D {
    func makeScene() throws -> Scene {
        let scene = Scene(name: "3D")
        
//        scene.addSystem(EditorCameraSystem.self)
        
//        let camera = EditorCameraEntity()
//        camera.components[Camera.self]?.isPrimal = true
//        scene.addEntity(camera)
        
        var transform = Transform()
        transform.scale = [10, 10, 10]

        let untexturedEntity = Entity(name: "Background")
        untexturedEntity.components += SpriteComponent(tintColor: Color.blue)
        untexturedEntity.components += transform
        scene.addEntity(untexturedEntity)
        
        let userEntity = Entity(name: "camera")
        let camera = Camera()
        camera.projection = .orthographic
        camera.isPrimal = true
        userEntity.components += camera
        scene.addEntity(userEntity)
        
//        let mesh = Mesh.generateBox(extent: [1, 1, 1], segments: [1, 1, 1])
        
//        let train = Entity(name: "Box")
//        train.components += ModelComponent(mesh: mesh)
//        scene.addEntity(train)
//
        return scene
    }
}
