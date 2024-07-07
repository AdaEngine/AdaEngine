//
//  TilemapScene.swift
//
//
//  Created by v.prusakov on 5/4/24.
//

import AdaEngine

class LdtkTilemapScene: Scene, TileMapDelegate {
    override func sceneDidMove(to view: SceneView) {
        self.debugOptions = [.showPhysicsShapes]
        
        let cameraEntity = OrthographicCamera()
        cameraEntity.camera.backgroundColor = Color(135/255, 206/255, 235/255, 1)
        cameraEntity.camera.clearFlags = .solid
        cameraEntity.camera.orthographicScale = 10.5
        
        self.addEntity(cameraEntity)
        
        var transform = Transform()
        transform.position.y = -0.5
        transform.scale = Vector3(0.5)
        
        do {
            let tileMap = try ResourceManager.loadSync("Assets/TestTileMap.ldtk", from: .editor) as LDtk.TileMap
            tileMap.delegate = self
            tileMap.loadLevel(at: 0)
            
            let tilemapEnt = Entity {
                TileMapComponent(tileMap: tileMap)
                NoFrustumCulling()
                transform
            }
            
            self.addEntity(tilemapEnt)
        } catch {
            fatalError("Failed to load \(error)")
        }
        
        self.addSystem(CamMovementSystem.self)
    }
    
    // MARK: - LDtk.EntityTileSourceDelegate
    
    func tileMap(_ tileMap: LDtk.TileMap, needsUpdate entity: Entity, from instance: LDtk.EntityInstance, in tileSource: LDtk.EntityTileSource) {
        
    }
}

class TilemapScene: Scene {
    
    enum TileAtlasCoordinates {
        static let topLeft: PointInt = [1, 5]
        static let topRight: PointInt = [3, 5]
        static let bottomLeft: PointInt = [1, 7]
        static let bottomRight: PointInt = [3, 7]
        static let middleTop: PointInt = [2, 5]
        static let middleBottom: PointInt = [2, 7]
        
        static let first: PointInt = [1, 6]
        static let last: PointInt = [3, 6]
        static let plain: PointInt = [2, 6]
        
        static let riverStart: PointInt = [14, 1]
        static let riverBody: PointInt = [14, 2]
        static let riverEnd: PointInt = [14, 3]
    }
    
    // swiftlint:disable:next function_body_length
    override func sceneDidMove(to view: SceneView) {
//        if FileSystem.current.itemExists(at: URL(filePath: "/Users/vprusakov/Downloads/tilemap.res")) {
//            loadIfNeeded()
//        } else {
            save()
//        }
    }
    
    private func loadIfNeeded() {
        let tileMap = try! ResourceManager.loadSync("/Users/vprusakov/Downloads/tilemap.res") as TileMap
        
        self.debugOptions = [.showPhysicsShapes]
        
        let cameraEntity = OrthographicCamera()
        cameraEntity.camera.backgroundColor = Color(135/255, 206/255, 235/255, 1)
        cameraEntity.camera.clearFlags = .solid
        cameraEntity.camera.orthographicScale = 1.5
        
        self.addEntity(cameraEntity)
        
        var transform = Transform()
        transform.position.y = -0.5
        transform.scale = Vector3(0.5)
        
        let tilemapEnt = Entity {
            TileMapComponent(tileMap: tileMap)
            NoFrustumCulling()
            transform
        }
        
        self.addEntity(tilemapEnt)
        self.addSystem(CamMovementSystem.self)
    }
    
    private func save() {
        let tileMap = TileMap()
        
        let image = try! ResourceManager.loadSync("Assets/tiles_packed.png", from: .editor) as Image
        let source = TextureAtlasTileSource(from: image, size: [18, 18])
        
        source.createTile(for: TileAtlasCoordinates.topLeft)
        source.createTile(for: TileAtlasCoordinates.topRight)
        source.createTile(for: TileAtlasCoordinates.bottomLeft)
        source.createTile(for: TileAtlasCoordinates.bottomRight)
        source.createTile(for: TileAtlasCoordinates.middleTop)
        source.createTile(for: TileAtlasCoordinates.middleBottom)
        
        source.createTile(for: TileAtlasCoordinates.last)
        source.createTile(for: TileAtlasCoordinates.first)
        source.createTile(for: TileAtlasCoordinates.plain)
        
        /// Add animated river
        source.createTile(for: TileAtlasCoordinates.riverStart)
            .setAnimationFrameColumns(2)
            .setAnimationFrameDuration(0.5)
        
        source.createTile(for: TileAtlasCoordinates.riverBody)
            .setAnimationFrameColumns(2)
            .setAnimationFrameDuration(0.5)
        
        source.createTile(for: TileAtlasCoordinates.riverEnd)
            .setAnimationFrameColumns(2)
            .setAnimationFrameDuration(0.5)
        
        let sourceId = tileMap.tileSet.addTileSource(source)
        
        let xRange = 0..<15
        let yRange = 0..<6
        
        for x in xRange {
            for y in yRange {
                let atlasCoordinates = getCoordinates(for: x, y: y, maxX: xRange.upperBound, maxY: yRange.upperBound)
                
                tileMap.layers[0].setCell(
                    at: [x, y],
                    sourceId: sourceId,
                    atlasCoordinates: atlasCoordinates
                )
            }
        }
        
        for y in yRange {
            let isStart = y == 0
            let isEnd = y == yRange.upperBound - 1
            
            var coordinates: PointInt = [0, 0]
            
            if isStart {
                coordinates = TileAtlasCoordinates.riverEnd
            } else if isEnd {
                coordinates = TileAtlasCoordinates.riverStart
            } else {
                coordinates = TileAtlasCoordinates.riverBody
            }
            
            tileMap.layers[0].setCell(
                at: [0, y],
                sourceId: sourceId,
                atlasCoordinates: coordinates
            )
        }
        
        self.debugOptions = [.showPhysicsShapes]
        
        let cameraEntity = OrthographicCamera()
        cameraEntity.camera.backgroundColor = Color(135/255, 206/255, 235/255, 1)
        cameraEntity.camera.clearFlags = .solid
        cameraEntity.camera.orthographicScale = 1.5
        
        self.addEntity(cameraEntity)
        
        var transform = Transform()
        transform.position.y = -0.5
        transform.scale = Vector3(0.5)
        
        let tilemapEnt = Entity {
            TileMapComponent(tileMap: tileMap)
            NoFrustumCulling()
            transform
        }
        
        self.addEntity(tilemapEnt)
        self.addSystem(CamMovementSystem.self)
        
        Task { @ResourceActor in
            do {
                try await ResourceManager.save(tileMap, at: "/Users/vprusakov/Downloads", name: "tilemap")
            } catch {
                print("Failed", error)
            }
        }
    }
    
    func getCoordinates(for x: Int, y: Int, maxX: Int, maxY: Int) -> PointInt {
        let isFirst = x == 0
        let isLast = x == maxX - 1
        
        let bottom = y == 0
        let top = y == maxY - 1
        
        if isFirst && top {
            return TileAtlasCoordinates.topLeft
        }
        
        if isFirst && bottom {
            return TileAtlasCoordinates.bottomLeft
        }
        
        if isLast && top {
            return TileAtlasCoordinates.topRight
        }
        
        if isLast && bottom {
            return TileAtlasCoordinates.bottomRight
        }
        
        if top {
            return TileAtlasCoordinates.middleTop
        }
        
        if bottom {
            return TileAtlasCoordinates.middleBottom
        }
        
        if isFirst {
            return TileAtlasCoordinates.first
        }
        
        if isLast {
            return TileAtlasCoordinates.last
        }
        
        return TileAtlasCoordinates.plain
    }
}

struct CamMovementSystem: System {
    
    static let cameraQuery = EntityQuery(where: .has(Camera.self) && .has(Transform.self))
    static let tileMap = EntityQuery(where: .has(TileMapComponent.self))
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        let cameraEntity: Entity = context.scene.performQuery(Self.cameraQuery).first!
//        let tileEntity: Entity = context.scene.performQuery(Self.tileMap).first!
        
//        if Input.isKeyPressed(.m) {
//            tileEntity.components[TileMapComponent.self]!.tileMap.layers[0].isEnabled.toggle()
//        }
        
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
