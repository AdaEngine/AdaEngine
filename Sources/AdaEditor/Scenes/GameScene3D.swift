//
//  GameScene3D.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 03.12.2024.
//

import AdaEngine

class GameScene3D: Scene, @unchecked Sendable {
    override func sceneDidMove(to view: SceneView) {
        let cameraEntity = PerspectiveCamera()
        cameraEntity.camera.backgroundColor = Color(135/255, 206/255, 235/255, 1)
        cameraEntity.camera.clearFlags = .solid
        self.addEntity(cameraEntity)


        let cube = Mesh.generateBox()
        let meshEntity = Entity {
            Transform()
            ModelComponent(mesh: cube)
        }

        self.addEntity(meshEntity)
    }
}
