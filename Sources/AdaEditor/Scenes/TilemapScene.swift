//
//  File.swift
//  
//
//  Created by v.prusakov on 5/4/24.
//

import AdaEngine

class TilemapScene {

    init() {
//        self.tileMap = try! ResourceManager.loadSync("Assets/characters_packed.png", from: Bundle.editor) as TileMap
    }

    @MainActor
    func makeScene() async throws -> Scene {
        let scene = Scene()

        let tileMap = TileMap()

        let image = try ResourceManager.loadSync("Assets/tiles_packed.png", from: .editor) as Image
        let source = TileTextureAtlasSource(from: image, size: [18, 18])

        let sourceId = tileMap.tileSet.addTileSource(source)

        for x in 0..<10 {
            for y in 0..<2 {
                tileMap.layers[0].setCell(at: [x, y], sourceId: sourceId, atlasCoordinates: [0, 0])
            }
        }

        scene.debugOptions = [.showPhysicsShapes]

        let cameraEntity = OrthographicCamera()
        cameraEntity.camera.backgroundColor = Color(135/255, 206/255, 235/255, 1)
        cameraEntity.camera.clearFlags = .solid
        cameraEntity.camera.orthographicScale = 1.5

        scene.addEntity(cameraEntity)

        var transform = Transform()
        transform.position.y = -0.5

        let tilemapEnt = Entity()
        tilemapEnt.components += TileMapComponent(tileMap: tileMap)
        tilemapEnt.components += NoFrustumCulling()
        tilemapEnt.components += transform

        scene.addEntity(tilemapEnt)
        scene.addSystem(PlayerMovementSystem.self)

        return scene
    }

}

struct CamMovementSystem: System {

    static let cameraQuery = EntityQuery(where: .has(Camera.self) && .has(Transform.self))

    init(scene: Scene) { }

    func update(context: UpdateContext) {
        let cameraEntity: Entity = context.scene.performQuery(Self.cameraQuery).first!

        var (camera, cameraTransform) = cameraEntity.components[Camera.self, Transform.self]

        let speed: Float = Input.isKeyPressed(.space) ? 5 : 2
        let speedNormalized: Float = speed * context.deltaTime

        if Input.isKeyPressed(.w) {
            cameraTransform.position.y += speedNormalized
        }

        if Input.isKeyPressed(.s) {
            cameraTransform.position.y -= speedNormalized
        }

        if Input.isKeyPressed(.a) {
            cameraTransform.position.x -= speedNormalized
        }

        if Input.isKeyPressed(.d) {
            cameraTransform.position.x += speedNormalized
        }

        if Input.isKeyPressed(.arrowUp) {
            camera.orthographicScale -= speedNormalized
        }

        if Input.isKeyPressed(.arrowDown) {
            camera.orthographicScale += speedNormalized
        }

        cameraEntity.components += cameraTransform
        cameraEntity.components += camera
    }
}
