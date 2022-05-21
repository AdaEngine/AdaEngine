//
//  File.swift
//  
//
//  Created by v.prusakov on 5/7/22.
//

import Yams

class ControlCircleComponent: ScriptComponent {
    
    var speed: Float = 4
    
//    @RequiredComponent var circle: Circle2DComponent
    @RequiredComponent var viewHolder: ViewContrainerComponent
    
    override func update(_ deltaTime: TimeInterval) {
//        if Input.isKeyPressed(.arrowUp) {
//            self.circle.thickness += 0.1
//        }
//
//        if Input.isKeyPressed(.arrowDown) {
//            self.circle.thickness -= 0.1
//        }
        
        let view = viewHolder.rootView//.subviews.last!

        if Input.isKeyPressed(.arrowDown) {
            view.frame.origin.y += 1 * speed
        }
        
        if Input.isKeyPressed(.arrowUp) {
            view.frame.origin.y -= 1 * speed
        }
        
        if Input.isKeyPressed(.arrowLeft) {
            view.frame.origin.x -= 1 * speed
        }
        
        if Input.isKeyPressed(.arrowRight) {
            view.frame.origin.x += 1 * speed
        }
    }
    
}

class GameScene {
    func makeScene() -> Scene {
        let scene = Scene()

        let view = View()
        view.backgroundColor = .red
//
//        let blueView = View()
//        blueView.frame = Rect(origin: Point(x: 0, y: 0), size: Size(width: 130, height: 130))
//        blueView.backgroundColor = Color.blue.opacity(0.2)
//        blueView.zIndex = -1
//        view.addSubview(blueView)
//        
//        let blueView1 = View()
//        blueView1.frame = Rect(origin: Point(x: 130, y: 0), size: Size(width: 130, height: 130))
//        blueView1.backgroundColor = Color.orange
//        blueView1.zIndex = 0
//        view.addSubview(blueView1)
//
//        let greenView = View()
//        greenView.frame = Rect(origin: Point(x: 30, y: 30), size: Size(width: 50, height: 50))
//        greenView.backgroundColor = Color.green
//        blueView.addSubview(greenView)
        
        
        let viewEntity = Entity(name: "View")
        viewEntity.components[ViewContrainerComponent.self] = ViewContrainerComponent(rootView: view)
        viewEntity.components[ControlCircleComponent.self] = ControlCircleComponent()
        scene.addEntity(viewEntity)
        
        
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
//
//        let userEntity = Entity(name: "user")
//        let camera = EditorCamera()
//        camera.isPrimal = true
//        userEntity.components.set(camera)
//
//        scene.addEntity(userEntity)
        
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
