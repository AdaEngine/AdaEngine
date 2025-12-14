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
