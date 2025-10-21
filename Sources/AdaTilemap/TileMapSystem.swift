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

    public init(world: World) { }

    public func update(context: inout UpdateContext) {
        let physicsWorld = context.world.getResource(Physics2DWorldComponent.self)?.world

        tileMap.forEach { (entity, tileMapComponent, transform) in
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
                    tileMapComponent: &tileMapComponent.wrappedValue,
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
        tileMapComponent: inout TileMapComponent,
        transform: Transform,
        entity: Entity,
        physicsWorld: PhysicsWorld2D?,
        world: World
    ) {
        guard let tileSet = layer.tileSet else { return }

        let scale = Vector3(1)
        if layer.needUpdates {
            tileMapComponent.tileLayers[layer.id]?.removeFromWorld(recursively: true)

            let tileParent = world.spawn()

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

                    tileEntity = world.spawn {
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
                world.addEntity(tileEntity)
            }
            world.addEntity(tileParent)
            tileMapComponent.tileLayers[layer.id] = tileParent
            layer.updateDidFinish()
        }
    }
}
