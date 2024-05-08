//
//  File.swift
//  
//
//  Created by v.prusakov on 5/4/24.
//

import AdaEngine

class TilemapScene: Scene {

    override func sceneDidMove(to view: SceneView) {
        let tileMap = TileMap()

        let image = try! ResourceManager.loadSync("Assets/tiles_packed.png", from: .editor) as Image
        let source = TileTextureAtlasSource(from: image, size: [18, 18])

        let sourceId = tileMap.tileSet.addTileSource(source)

        let xRange = 0..<15
        let yRange = 0..<6

        for x in xRange {
            for y in yRange {
                let point = getCoordinates(for: x, y: y, maxX: xRange.upperBound, maxY: yRange.upperBound)

                tileMap.layers[0].setCell(
                    at: [x, y],
                    sourceId: sourceId,
                    atlasCoordinates: point
                )
            }
        }

//        scene.debugOptions = [.showPhysicsShapes]

        let cameraEntity = OrthographicCamera()
        cameraEntity.camera.backgroundColor = Color(135/255, 206/255, 235/255, 1)
        cameraEntity.camera.clearFlags = .solid
        cameraEntity.camera.orthographicScale = 1.5

        self.addEntity(cameraEntity)

        var transform = Transform()
        transform.position.y = -0.5
        transform.scale = Vector3(0.5)

        let tilemapEnt = Entity()
        tilemapEnt.components += TileMapComponent(tileMap: tileMap)
        tilemapEnt.components += NoFrustumCulling()
        tilemapEnt.components += transform

        self.addEntity(tilemapEnt)
        self.addSystem(CamMovementSystem.self)
    }

    @MainActor
    func makeScene() async throws -> Scene {
        let scene = Scene()



        return scene
    }

    func getCoordinates(for x: Int, y: Int, maxX: Int, maxY: Int) -> PointInt {
        let isFirst = x == 0
        let isLast = x == maxX - 1

        let bottom = y == 0
        let top = y == maxY - 1

        let topLeft: PointInt = [1, 5]
        let topRight: PointInt = [3, 5]
        let bottomLeft: PointInt = [1, 7]
        let bottomRight: PointInt = [3, 7]
        let middleTop: PointInt = [2, 5]
        let middleBottom: PointInt = [2, 7]

        if isFirst && top {
            return topLeft
        }

        if isFirst && bottom {
            return bottomLeft
        }

        if isLast && top {
            return topRight
        }

        if isLast && bottom {
            return bottomRight
        }

        if top {
            return middleTop
        }

        if bottom {
            return middleBottom
        }

        if isFirst {
            return [1, 6]
        }

        if isLast {
            return [3, 6]
        }

        return [2, 6]
    }

}

struct CamMovementSystem: System {

    static let cameraQuery = EntityQuery(where: .has(Camera.self) && .has(Transform.self))
    static let tileMap = EntityQuery(where: .has(TileMapComponent.self))

    init(scene: Scene) { }

    func update(context: UpdateContext) {
        let cameraEntity: Entity = context.scene.performQuery(Self.cameraQuery).first!
        let tileEntity: Entity = context.scene.performQuery(Self.tileMap).first!

        if Input.isKeyPressed(.m) {
            tileEntity.components[TileMapComponent.self]!.tileMap.layers[0].isEnabled.toggle()
        }

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
