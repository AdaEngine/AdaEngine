//
//  TileMapSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/5/24.
//

import AdaAssets
import AdaECS
import AdaTransform
import AdaPhysics
import AdaSprite
import Logging
import Math
import OrderedCollections

// FIXME: a lot of sprites drop fps.
@PlainSystem
public struct TileMapSystem: Sendable {
    
    let logger = Logger(label: "tilemap")

    @Query<Entity, Ref<TileMapComponent>, Transform>
    private var tileMap

    @Res<Physics2DWorldComponent?>
    private var physicsWorld

    @Commands
    private var commands

    public init(world: World) { }

    public func update(context: UpdateContext) {
        let physicsWorld = physicsWorld?.world

        tileMap.forEach { (entity, tileMapComponent, transform) in
            let tileMap = tileMapComponent.tileMap

            if !tileMap.needsUpdate {
                return
            }

            for layer in tileMap.layers {
                if
                    let entityId = tileMapComponent.tileLayers[layer.id],
                    let entity = context.world.getEntityByID(entityId)
                {
                    self.setEntityActive(entity, isActive: layer.isEnabled)
                }

                self.addTiles(
                    for: layer,
                    tileMapComponent: tileMapComponent,
                    transform: transform,
                    entity: entity,
                    physicsWorld: physicsWorld,
                    world: context.world
                )
            }
            tileMap.updateDidFinish()
        }
    }

    private func setEntityActive(_ entity: Entity, isActive: Bool) {
        entity.isActive = isActive

        for child in entity.children {
            child.isActive = isActive
        }
    }

    private func addTiles(
        for layer: TileMapLayer,
        tileMapComponent: Ref<TileMapComponent>,
        transform: Transform,
        entity: Entity,
        physicsWorld: PhysicsWorld2D?,
        world: World
    ) {
        guard let tileSet = layer.tileSet else { return }

        let scale = Vector3(1)
        if layer.needUpdates {
            if let entity = tileMapComponent.tileLayers[layer.id] {
                commands.entity(entity).removeFromWorld(recursively: true)
            }

            let tileParent = commands.spawn() {
                RelationshipComponent()
            }

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

                    tileEntity = Entity {
                        SpriteComponent(
                            texture: AssetHandle(texture),
                            tintColor: tileData.modulateColor
                        )
                        Transform(scale: scale, position: position)
                    }
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
            }
            tileMapComponent.tileLayers[layer.id] = tileParent.entityId
            layer.updateDidFinish()
        }
    }
}
