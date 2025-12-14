//
//  CustomTileMapExample.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 14.12.2025.
//

import AdaEngine

struct CustomTileMapExample: App {
    var body: some AppScene {
        EmptyWindow()
            .addPlugins(
                CustomTileMapPlugin(),
                DefaultPlugins()
            )
            .windowMode(.windowed)
    }
}

struct CustomTileMapPlugin: Plugin {
    func setup(in app: borrowing AppWorlds) {
        app.addSystem(InputControlSystem.self)
    }
}

@PlainSystem
struct InputControlSystem {

    @Res<Input>
    private var input

    @Commands
    private var commands


    init(world: World) { }

    func update(context: UpdateContext) async {
        do {
            if input.isKeyPressed(.space) {
                try await loadIfNeeded()
            } else {
                try await save()
            }
        } catch {
            assertionFailure(error.localizedDescription)
        }
    }

    private func loadIfNeeded() async throws {
        let tileMap = try await AssetsManager.load(
            TileMap.self,
            at: "@res://tilemap.res",
        ).asset!

        var cameraBundle = Camera2D()
        cameraBundle.camera.backgroundColor = Color(135/255, 206/255, 235/255, 1)
        cameraBundle.camera.clearFlags = .solid
        cameraBundle.camera.orthographicScale = 1.5

        commands.spawn(bundle: cameraBundle)

        var transform = Transform()
        transform.position.y = -0.5
        transform.scale = Vector3(0.5)

        let tilemapEnt = commands.spawn { [transform] in
            TileMapComponent(tileMap: tileMap)
            NoFrustumCulling()
            transform
        }
    }
}

private extension InputControlSystem {
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

    private func save() async throws {
        let tileMap = TileMap()

        let image = try await AssetsManager.load(
            Image.self,
            at: "Assets/tiles_packed.png"
        ).asset!
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

        // Add animated river
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

        var cameraEntity = Camera2D()
        cameraEntity.camera.backgroundColor = Color(135/255, 206/255, 235/255, 1)
        cameraEntity.camera.clearFlags = .solid
        cameraEntity.camera.orthographicScale = 1.5

        var transform = Transform()
        transform.position.y = -0.5
        transform.scale = Vector3(0.5)

        let tilemapEnt = commands.spawn { [transform] in
            TileMapComponent(tileMap: tileMap)
            NoFrustumCulling()
            transform
        }

        try await AssetsManager.save(tileMap, at: "@res://", name: "tilemap")
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
