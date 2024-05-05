//
//  TileMapSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/5/24.
//

public struct TileMapSystem: System {

    public static var dependencies: [SystemDependency] = [
        .after(VisibilitySystem.self)
    ]

    static let tileMap = EntityQuery(where: .has(TileMapComponent.self) && .has(Transform.self))
    static let physicsWorld = EntityQuery(where: .has(Physics2DWorldComponent.self))

    public init(scene: Scene) { }

    public func update(context: UpdateContext) async {
        let physicsWorldEntity = context.scene.performQuery(Self.physicsWorld).first
        let physicsWorld = physicsWorldEntity?.components[Physics2DWorldComponent.self]?.world

        for entity in context.scene.performQuery(Self.tileMap) {
            var (tileMapComponent, transform) = entity.components[TileMapComponent.self, Transform.self]
            let tileMap = tileMapComponent.tileMap

            for layer in tileMap.layers where layer.isEnabled {
                await self.addTiles(
                    for: layer,
                    tileMapComponent: &tileMapComponent,
                    transform: transform,
                    entity: entity,
                    physicsWorld: physicsWorld,
                    scene: context.scene
                )
            }

            entity.components += tileMapComponent
        }
    }

    public func addTiles(
        for layer: TileMapLayer,
        tileMapComponent: inout TileMapComponent,
        transform: Transform,
        entity: Entity,
        physicsWorld: PhysicsWorld2D?,
        scene: Scene
    ) async {
        guard let tileSet = layer.tileSet else {
            return
        }

        let gridSize = 1 / Float(layer.gridSize)

        if layer.needUpdates {
            tileMapComponent.tileLayers[layer.id]?.removeFromScene(recursively: true)

            let tileParent = Entity()

            for (position, tile) in layer.tileMap {
                guard let source = tileSet.sources[tile.sourceId] else {
                    continue
                }

                let texture = source.getTexture(at: tile.coordinates)

                let tileEntity = Entity()
                tileEntity.components += SpriteComponent(texture: texture, tintColor: .white)
                tileEntity.components += Transform(scale: [gridSize, gridSize, gridSize], position: [Float(position.x), Float(position.y), 1])
                tileEntity.components += Collision2DComponent(
                    shapes: [.generateBox(width: gridSize, height: gridSize)],
                    filter: CollisionFilter(categoryBitMask: .default, collisionBitMask: .default) // TODO: Change
                )

                tileParent.addChild(tileParent)
                scene.addEntity(tileEntity)
            }

            scene.addEntity(tileParent)

            tileMapComponent.tileLayers[layer.id] = tileParent

            layer.updateDidFinish()
        }
//
//        let extractedEntity = EmptyEntity()
//        var extractedSprites = ExtractedSprites(sprites: [])
//
//        let gridSize = Float(layer.gridSize)
//
//        for (position, tile) in layer.tileMap {
//            guard let source = tileSet.sources[tile.sourceId] else {
//                continue
//            }
//
//            let texture = source.getTexture(at: tile.coordinates)
//
//            let tileTransformMat = Transform3D(
//                translation: [Float(position.x), Float(position.y), 1],
//                rotation: .identity,
//                scale: [gridSize, gridSize, gridSize]
//            ) * transform.matrix
//
//            extractedSprites.sprites.append(
//                ExtractedSprite(
//                    entityId: entityId,
//                    texture: texture,
//                    tintColor: Color.white,
//                    transform: Transform(matrix: tileTransformMat),
//                    worldTransform: tileTransformMat
//                )
//            )
//        }
//
//        extractedEntity.components += extractedSprites
//
//        await Application.shared.renderWorld.addEntity(extractedEntity)
    }
}
