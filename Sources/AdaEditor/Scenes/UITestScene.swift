//
//  UITesScene.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 19.08.2024.
//

import AdaEngine

struct SomeContent: View {

    @Environment(\.scene) var scene
    @Environment(\.entity) var entity

    var body: some View {
        VStack {
            Color.blue

            Color.green
        }
        .onAppear {
            print(scene, entity)
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
            Transform(scale: Vector3(0.5), position: [0.5, 0, 0])
        }

        self.addEntity(entity)

        let uiEntity = Entity {
            UIComponent(
                view: SomeContent().frame(width: 150, height: 150),
                behaviour: .overlay
            )
            
            Transform(scale: Vector3(0.5), position: [0.5, 0, 0])
        }
        self.addEntity(uiEntity)

        let container = UIContainerView(rootView: Color.blue)
        container.backgroundColor = .surfaceClearColor
        container.frame = Rect(x: 0, y: 0, width: 200, height: 200)
        view.addSubview(container)
    }
}
