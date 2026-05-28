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
        DefaultAppWindow()
            .addPlugins(
                LdtkTilemapPlugin()
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
            )
        )

        app.main.addSystem(SetupLdtkTilemapSystem.self, on: .startup)
        app.main.addSystem(CamMovementSystem.self)
    }
}

@System
func SetupLdtkTilemap(_ commands: Commands) async {
    do {
        let tileMap = try await AssetsManager.load(
            LDtk.TileMap.self,
            at: "Resources/TestTileMap.ldtk",
            from: .module
        ).asset!
        tileMap.loadLevel(at: 0)

        commands.spawn {
            TileMapComponent(
                tileMap: tileMap,
                tileDisplaySize: Size(width: 48, height: 48)
            )
            Transform()
        }
    } catch {
        fatalError("Failed to load \(error)")
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
        let (_, cameraTransform) = cameras.first!
        let tileMap = tileMaps.first!

        if input.isKeyPressed(.m) {
            tileMap.tileMap.layers[0].isEnabled.toggle()
        }
        
        let speed: Float = input.isKeyPressed(.space) ? 500 : 200
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
    }
}
