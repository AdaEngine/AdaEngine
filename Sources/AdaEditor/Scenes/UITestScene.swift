//
//  UITesScene.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 19.08.2024.
//

import AdaEngine

struct SomeContent: View {
    var body: some View {
        VStack {
            Color.blue
            Color.green
        }
    }
}

class UITestScene: Scene {
    override func sceneDidMove(to view: SceneView) {
        let cameraEntity = OrthographicCamera()
        cameraEntity.camera.backgroundColor = Color(135/255, 206/255, 235/255, 1)
        cameraEntity.camera.clearFlags = .solid
        cameraEntity.camera.orthographicScale = 1.5
        self.addEntity(cameraEntity)

        let entity = Entity {
            SpriteComponent(tintColor: .red)
            Transform(scale: Vector3(0.5), position: [0, 0, 0])
        }

        self.addEntity(entity)

        let container = UIContainerView(rootView: SomeContent())
        container.autoresizingRules = [.flexibleWidth, .flexibleHeight]
        view.addSubview(container)
    }
}
