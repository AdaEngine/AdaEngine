//
//  File.swift
//  
//
//  Created by v.prusakov on 5/7/22.
//

import AdaEngine

class ControlCircleComponent: ScriptComponent {
    
    var speed: Float = 4
    
    @RequiredComponent var circle: Circle2DComponent
    
    override func ready() {
        self.transform.scale = [0.2, 0.2, 0.2]
    }
    
    override func update(_ deltaTime: TimeInterval) {
        if Input.isKeyPressed(.arrowUp) {
            self.circle.thickness += 0.1
        }

        if Input.isKeyPressed(.arrowDown) {
            self.circle.thickness -= 0.1
        }

        if Input.isKeyPressed(.w) {
            self.transform.position.y -= 0.1 * speed
        }

        if Input.isKeyPressed(.s) {
            self.transform.position.y += 0.1 * speed
        }

        if Input.isKeyPressed(.a) {
            self.transform.position.x -= 0.1 * speed
        }

        if Input.isKeyPressed(.d) {
            self.transform.position.x += 0.1 * speed
        }
        
    }
    
}

class GameScene {
    func makeScene() -> Scene {
        let scene = Scene()

//        
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
//        trainEntity.components[Transform.self]?.position = Vector3(2, 1, 1)
//        scene.addEntity(trainEntity)
//
        
        let viewEntity = Entity(name: "Circle")
        viewEntity.components += Circle2DComponent(color: .red, thickness: 1)
        viewEntity.components += ControlCircleComponent()
        scene.addEntity(viewEntity)
        
        let viewEntity1 = Entity(name: "Circle")
        viewEntity1.components += Circle2DComponent(color: .yellow, thickness: 0.3)
        viewEntity1.components[Transform.self]!.position = [4, 4, 4]
        viewEntity1.components[Transform.self]!.scale = [0.2, 0.2, 0.2]
        scene.addEntity(viewEntity1)
        
        let userEntity = Entity(name: "camera")
        let camera = Camera()
        camera.projection = .orthographic
        camera.isPrimal = true
        camera.near = 0
        camera.far = 1
        userEntity.components += camera
        scene.addEntity(userEntity)
        
//        let editorCamera = EditorCameraEntity()
//        let camera = editorCamera.components[Camera.self]!
//        camera.isPrimal = true
//        scene.addEntity(editorCamera)
//
//        scene.addSystem(EditorCameraSystem.selfa)
        
        return scene
    }
    
}
