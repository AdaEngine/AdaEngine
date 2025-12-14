//
//  TilemapScene.swift
//
//
//  Created by v.prusakov on 5/4/24.
//

import AdaEngine

@main
struct LdtkTilemapExampleApp: App {
    var body: some AppScene {
        EmptyWindow()
            .addPlugins(
                LdtkTilemapPlugin(),
                DefaultPlugins()
            )
            .windowMode(.windowed)
    }
}


final class LdtkTilemapPlugin: Plugin {
    func setup(in app: borrowing AppWorlds) {
        app.main.spawn(
            bundle: Camera2D(
                camera: Camera()
                    .setBackgroundColor(Color(135/255, 206/255, 235/255, 1))
                    .setOrthographicScale(10.5)
            )
        )

        var transform = Transform()
        transform.position.y = -0.5
        transform.scale = Vector3(0.5)

        do {
            let tileMap = try AssetsManager.loadSync(
                LDtk.TileMap.self,
                at: "Resources/TestTileMap.ldtk",
                from: .module
            ).asset!
            tileMap.delegate = self
            tileMap.loadLevel(at: 0)

            app.main.spawn {
                TileMapComponent(tileMap: tileMap)
                NoFrustumCulling()
                transform
            }
        } catch {
            fatalError("Failed to load \(error)")
        }

        app.main.addSystem(CamMovementSystem.self)
    }
}

extension LdtkTilemapPlugin: TileMapDelegate {
    func tileMap(
        _ tileMap: LDtk.TileMap,
        needsUpdate entity: Entity,
        from instance: LDtk.EntityInstance,
        in tileSource: LDtk.EntityTileSource
    ) {

    }
}

//final class TilemapScene: Scene, @unchecked Sendable {
//    
//    enum TileAtlasCoordinates {
//        static let topLeft: PointInt = [1, 5]
//        static let topRight: PointInt = [3, 5]
//        static let bottomLeft: PointInt = [1, 7]
//        static let bottomRight: PointInt = [3, 7]
//        static let middleTop: PointInt = [2, 5]
//        static let middleBottom: PointInt = [2, 7]
//        
//        static let first: PointInt = [1, 6]
//        static let last: PointInt = [3, 6]
//        static let plain: PointInt = [2, 6]
//        
//        static let riverStart: PointInt = [14, 1]
//        static let riverBody: PointInt = [14, 2]
//        static let riverEnd: PointInt = [14, 3]
//    }
//    
//    override func sceneDidMove(to view: SceneView) {
////        if FileSystem.current.itemExists(at: URL(filePath: "/Users/vprusakov/Downloads/tilemap.res")) {
////            loadIfNeeded()
////        } else {
//            save()
////        }
//    }
//    
//    private func loadIfNeeded() {
//        let tileMap = try! AssetsManager.loadSync(
//            TileMap.self, 
//            at: "/Users/vprusakov/Downloads/tilemap.res", 
//            from: .editor
//        ).asset
//        
//        let cameraEntity = OrthographicCamera()
//        cameraEntity.camera.backgroundColor = Color(135/255, 206/255, 235/255, 1)
//        cameraEntity.camera.clearFlags = .solid
//        cameraEntity.camera.orthographicScale = 1.5
//        
//        self.world.addEntity(cameraEntity)
//        
//        var transform = Transform()
//        transform.position.y = -0.5
//        transform.scale = Vector3(0.5)
//        
//        let tilemapEnt = Entity {
//            TileMapComponent(tileMap: tileMap)
//            NoFrustumCulling()
//            transform
//        }
//        
//        self.world.addEntity(tilemapEnt)
//        self.world.addSystem(CamMovementSystem.self)
//    }
//
//    // swiftlint:disable:next function_body_length
//    private func save() {
//        let tileMap = TileMap()
//        
//        let image = try! AssetsManager.loadSync(
//            Image.self, 
//            at: "Assets/tiles_packed.png"
//        ).asset
//        let source = TextureAtlasTileSource(from: image, size: [18, 18])
//        
//        source.createTile(for: TileAtlasCoordinates.topLeft)
//        source.createTile(for: TileAtlasCoordinates.topRight)
//        source.createTile(for: TileAtlasCoordinates.bottomLeft)
//        source.createTile(for: TileAtlasCoordinates.bottomRight)
//        source.createTile(for: TileAtlasCoordinates.middleTop)
//        source.createTile(for: TileAtlasCoordinates.middleBottom)
//        
//        source.createTile(for: TileAtlasCoordinates.last)
//        source.createTile(for: TileAtlasCoordinates.first)
//        source.createTile(for: TileAtlasCoordinates.plain)
//        
//        // Add animated river
//        source.createTile(for: TileAtlasCoordinates.riverStart)
//            .setAnimationFrameColumns(2)
//            .setAnimationFrameDuration(0.5)
//        
//        source.createTile(for: TileAtlasCoordinates.riverBody)
//            .setAnimationFrameColumns(2)
//            .setAnimationFrameDuration(0.5)
//        
//        source.createTile(for: TileAtlasCoordinates.riverEnd)
//            .setAnimationFrameColumns(2)
//            .setAnimationFrameDuration(0.5)
//        
//        let sourceId = tileMap.tileSet.addTileSource(source)
//        
//        let xRange = 0..<15
//        let yRange = 0..<6
//        
//        for x in xRange {
//            for y in yRange {
//                let atlasCoordinates = getCoordinates(for: x, y: y, maxX: xRange.upperBound, maxY: yRange.upperBound)
//                
//                tileMap.layers[0].setCell(
//                    at: [x, y],
//                    sourceId: sourceId,
//                    atlasCoordinates: atlasCoordinates
//                )
//            }
//        }
//        
//        for y in yRange {
//            let isStart = y == 0
//            let isEnd = y == yRange.upperBound - 1
//            
//            var coordinates: PointInt = [0, 0]
//            
//            if isStart {
//                coordinates = TileAtlasCoordinates.riverEnd
//            } else if isEnd {
//                coordinates = TileAtlasCoordinates.riverStart
//            } else {
//                coordinates = TileAtlasCoordinates.riverBody
//            }
//            
//            tileMap.layers[0].setCell(
//                at: [0, y],
//                sourceId: sourceId,
//                atlasCoordinates: coordinates
//            )
//        }
//        
//        let cameraEntity = OrthographicCamera()
//        cameraEntity.camera.backgroundColor = Color(135/255, 206/255, 235/255, 1)
//        cameraEntity.camera.clearFlags = .solid
//        cameraEntity.camera.orthographicScale = 1.5
//        
//        self.world.addEntity(cameraEntity)
//        
//        var transform = Transform()
//        transform.position.y = -0.5
//        transform.scale = Vector3(0.5)
//        
//        let tilemapEnt = Entity {
//            TileMapComponent(tileMap: tileMap)
//            NoFrustumCulling()
//            transform
//        }
//        
//        self.world.addEntity(tilemapEnt)
//        self.world.addSystem(CamMovementSystem.self)
//        
//        Task { @AssetActor in
//            do {
//                try await AssetsManager.save(tileMap, at: "/Users/vprusakov/Downloads", name: "tilemap")
//            } catch {
//                print("Failed", error)
//            }
//        }
//    }
//    
//    func getCoordinates(for x: Int, y: Int, maxX: Int, maxY: Int) -> PointInt {
//        let isFirst = x == 0
//        let isLast = x == maxX - 1
//        
//        let bottom = y == 0
//        let top = y == maxY - 1
//        
//        if isFirst && top {
//            return TileAtlasCoordinates.topLeft
//        }
//        
//        if isFirst && bottom {
//            return TileAtlasCoordinates.bottomLeft
//        }
//        
//        if isLast && top {
//            return TileAtlasCoordinates.topRight
//        }
//        
//        if isLast && bottom {
//            return TileAtlasCoordinates.bottomRight
//        }
//        
//        if top {
//            return TileAtlasCoordinates.middleTop
//        }
//        
//        if bottom {
//            return TileAtlasCoordinates.middleBottom
//        }
//        
//        if isFirst {
//            return TileAtlasCoordinates.first
//        }
//        
//        if isLast {
//            return TileAtlasCoordinates.last
//        }
//        
//        return TileAtlasCoordinates.plain
//    }
//}

@PlainSystem
struct CamMovementSystem {

    @Query<Ref<Camera>, Ref<Transform>>
    private var cameras

    @Query<TileMapComponent>
    private var tileMaps

    @Res<Input>
    private var input

    @Res<DeltaTime>
    private var deltaTime

    init(world: World) { }
    
    func update(context: UpdateContext) {
        let (camera, cameraTransform) = cameras.first!
        let tileMap = tileMaps.first!

        if input.isKeyPressed(.m) {
            tileMap.tileMap.layers[0].isEnabled.toggle()
        }
        
        let speed: Float = input.isKeyPressed(.space) ? 5 : 2
        let speedNormalized: Float = speed * deltaTime.deltaTime

        if input.isKeyPressed(.w) {
            cameraTransform.position.y += speedNormalized
        }
        
        if input.isKeyPressed(.s) {
            cameraTransform.position.y -= speedNormalized
        }
        
        if input.isKeyPressed(.a) {
            cameraTransform.position.x -= speedNormalized
        }
        
        if input.isKeyPressed(.d) {
            cameraTransform.position.x += speedNormalized
        }
        
        if input.isKeyPressed(.arrowUp) {
            camera.orthographicScale -= speedNormalized
        }
        
        if input.isKeyPressed(.arrowDown) {
            camera.orthographicScale += speedNormalized
        }
    }
}
