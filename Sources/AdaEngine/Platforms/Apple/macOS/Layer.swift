//
//  File.swift
//  
//
//  Created by v.prusakov on 5/7/22.
//

import Yams

class ControllCircleComponent: ScriptComponent {
    
    @RequiredComponent var circle: Circle2DComponent
    
    override func update(_ deltaTime: TimeInterval) {
        if Input.isKeyPressed(.arrowUp) {
            self.circle.thickness += 0.1
        }
        
        if Input.isKeyPressed(.arrowDown) {
            self.circle.thickness -= 0.1
        }

        if Input.isKeyPressed(.arrowLeft) {
            self.transform.position.y -= 1
        }
        
        if Input.isKeyPressed(.arrowRight) {
            self.transform.position.y += 1
        }
    }
}

class GameScene {
    func makeScene() -> Scene {
        let scene = Scene()
        
        let boxEntity = Entity(name: "box-1")
        boxEntity.components[Circle2DComponent.self] = Circle2DComponent(color: .orange)
        
        boxEntity.components[ControllCircleComponent.self] = ControllCircleComponent()
        scene.addEntity(boxEntity)
        
        let boxEntity1 = Entity(name: "box-2")
        boxEntity1.components[Circle2DComponent.self] = Circle2DComponent(
            color: .green,
            thickness: 0.1
        )
        
        boxEntity1.components[Transform.self]?.position.x = 0.4
        scene.addEntity(boxEntity1)
        
//        let meshRenderer = MeshRenderer()
//        meshRenderer.materials = [BaseMaterial(diffuseColor: .red, metalic: 0)]
//        let mesh = Mesh.generateBox(extent: Vector3(1, 1, 1), segments: Vector3(1, 1, 1))
//
//        meshRenderer.mesh = mesh
//        boxEntity.components[MeshRenderer.self] = meshRenderer
//        scene.addEntity(boxEntity)
//
//        let trainEntity = Entity(name: "train")
//        let trainMeshRenderer = MeshRenderer()
//        let train = Bundle.module.url(forResource: "train", withExtension: "obj")!
//
//        trainMeshRenderer.mesh = Mesh.loadMesh(from: train)
//        trainMeshRenderer.materials = [BaseMaterial(diffuseColor: .orange, metalic: 1)]
//        trainEntity.components[MeshRenderer.self] = trainMeshRenderer
////        trainEntity.components[Transform.self]?.position = Vector3(2, 1, 1)
//        scene.addEntity(trainEntity)
        
        let userEntity = Entity(name: "user")
        let camera = EditorCamera()
        camera.isPrimal = true
        userEntity.components.set(camera)
        
        scene.addEntity(userEntity)
        
//
//        let decoder = YAMLDecoder()
//        let encoder = YAMLEncoder()
//        do {
//            let data = try encoder.encode(scene)
//            print(data)
//            let newScene = try decoder.decode(Scene.self, from: data)
//            SceneManager.shared.presentScene(newScene)
//        } catch {
//            print(error)
//        }
//
        RenderEngine.shared.renderBackend.setClearColor(Color(212/255, 210/255, 213/255, 1))
        
        return scene
    }
    
}
