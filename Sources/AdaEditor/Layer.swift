//
//  File.swift
//  
//
//  Created by v.prusakov on 5/7/22.
//

import AdaEngine

class ControlCircleComponent: ScriptComponent {
    
    var speed: Float = 4
    
//    @RequiredComponent var circle: Circle2DComponent
    @RequiredComponent var viewHolder: ViewContrainerComponent
    
    override func ready() {
//        RenderEngine.shared.setClearColor(Color(212/255, 210/255, 213/255, 1), forWindow: <#Window.ID#>)
    }
    
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
        view.backgroundColor = .blue
//
//        let blueView = View()
//        blueView.zIndex = 1
//        blueView.frame = Rect(origin: Point(x: 1600 / 2, y: 0), size: Size(width: 1600 / 2, height: 1144 / 2))
//        blueView.backgroundColor = Color.blue.opacity(0.2)
//        view.addSubview(blueView)
//
//        let greenView = View()
//        greenView.zIndex = 2
//        greenView.frame = Rect(origin: Point(x: 30, y: 30), size: Size(width: 50, height: 50))
//        greenView.backgroundColor = Color.green
//        blueView.addSubview(greenView)
//
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
//        trainEntity.components[Transform.self]?.position = Vector3(2, 1, 1)
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
        
        return scene
    }
    
}

class EditorWindow: Window {
    
    override func windowDidReady() {
        self.title = "Ada Editor"
        self.canDraw = true
        
        let blueView = View(frame: .init(origin: .zero, size: Size(width: 30, height: 30)))
        blueView.backgroundColor = .blue
        
        self.addSubview(blueView)
    }
}
