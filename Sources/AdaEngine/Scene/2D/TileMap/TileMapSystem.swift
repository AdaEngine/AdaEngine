//
//  TileMapSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/5/24.
//

import AdaECS
import Logging

// FIXME: a lot of sprites drop fps.

public struct TileMapSystem: System, Sendable {
    
    let logger = Logger(label: "tilemap")

    public static let dependencies: [SystemDependency] = [
        .after(VisibilitySystem.self)
    ]

    static let tileMap = EntityQuery(where: .has(TileMapComponent.self) && .has(Transform.self))
    static let physicsWorld = EntityQuery(where: .has(Physics2DWorldComponent.self))

    public init(world: World) { }

    public func update(context: UpdateContext) {
        let physicsWorldEntity = context.world.performQuery(Self.physicsWorld).first
        let physicsWorld = physicsWorldEntity?.components[Physics2DWorldComponent.self]?.world

        for entity in context.world.performQuery(Self.tileMap) {
            context.scheduler.addTask { @MainActor in
                var (tileMapComponent, transform) = entity.components[TileMapComponent.self, Transform.self]
                let tileMap = tileMapComponent.tileMap

                if !tileMap.needsUpdate {
                    return
                }
                
                for layer in tileMap.layers {
                    if let ent = tileMapComponent.tileLayers[layer.id] {
                        self.setEntityActive(ent, isActive: layer.isEnabled)
                    }

                    self.addTiles(
                        for: layer,
                        tileMapComponent: &tileMapComponent,
                        transform: transform,
                        entity: entity,
                        physicsWorld: physicsWorld,
                        world: context.world
                    )
                }

                entity.components += tileMapComponent
                tileMap.updateDidFinish()
            }
            
        }
    }

    private func setEntityActive(_ entity: Entity, isActive: Bool) {
        entity.isActive = isActive

        for child in entity.children {
            child.isActive = isActive
        }
    }

    @MainActor
    private func addTiles(
        for layer: TileMapLayer,
        tileMapComponent: inout TileMapComponent,
        transform: Transform,
        entity: Entity,
        physicsWorld: PhysicsWorld2D?,
        world: World
    ) {
        guard let tileSet = layer.tileSet else { return }

        let scale = Vector3(1)
        if layer.needUpdates {
            tileMapComponent.tileLayers[layer.id]?.removeFromScene(recursively: true)

            let tileParent = Entity()

            for (position, tile) in layer.tileCells {
                guard let source = tileSet.sources[tile.sourceId] else {
                    assertionFailure("TileSource not found for id: \(tile.sourceId)")
                    continue
                }

                let tileData = source.getTileData(at: tile.atlasCoordinates)
                let position = Vector3(x: Float(position.x), y: Float(position.y), z: Float(layer.zIndex))

                let tileEntity: Entity

                switch source {
                case let atlasSource as TextureAtlasTileSource:
                    let texture = atlasSource.getTexture(at: tile.atlasCoordinates)

                    tileEntity = Entity()
                    tileEntity.components += SpriteComponent(texture: texture, tintColor: tileData.modulateColor)
                    tileEntity.components += Transform(scale: scale, position: position)
                case let entitySource as TileEntityAtlasSource:
                    tileEntity = entitySource.getEntity(at: tile.atlasCoordinates)
                    tileEntity.components += Transform(scale: scale, position: position)
                default:
                    logger.warning("TileSource isn't supported for id: \(tile.sourceId)")
                    continue
                }

//                if tileData.useCollisition {
//                    tileEntity.components += Collision2DComponent(
//                        shapes: [.generateBox()],
//                        filter: CollisionFilter(
//                            categoryBitMask: tileData.physicLayer.collisionLayer,
//                            collisionBitMask: tileData.physicLayer.collisionMask
//                        )
//                    )
//                }

                tileParent.addChild(tileEntity)
                world.addEntity(tileEntity)
            }
            world.addEntity(tileParent)
            tileMapComponent.tileLayers[layer.id] = tileParent
            layer.updateDidFinish()
        }
    }
}
