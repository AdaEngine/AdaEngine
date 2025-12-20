//
//  TileMapPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/4/24.
//

import AdaApp
import AdaAssets
import AdaECS
import AdaTransform
import AdaPhysics
import AdaSprite
import Logging
import Math
import OrderedCollections

public struct TileMapPlugin: Plugin {

    public init() {}

    public func setup(in app: AppWorlds) {
        TileMapComponent.registerComponent()
        
        TextureAtlasTileSource.registerTileSource()
        TileEntityAtlasSource.registerTileSource()

        app.addSystem(TileMapSystem.self)
    }
}

@PlainSystem
public struct TileMapSystem: Sendable {

    private let logger = Logger(label: "org.adaengine.tilemap")

    @Query<Entity, Ref<TileMapComponent>, Transform>
    private var tileMap

    @Res<Physics2DWorldHolder?>
    private var physicsWorld

    @Commands
    private var commands

    public init(world: World) { }

    public func update(context: UpdateContext) {
        tileMap.forEach { entity, tileMapComponent, transform in
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
        world: World
    ) {
        let tileSize = tileMapComponent.wrappedValue.tileDisplaySize
        guard let tileSet = layer.tileSet else {
            logger.error("TileSet not found for tiles", metadata: [
                "layer": .string(layer.id.description)
            ])
            return
        }

        if layer.needUpdates {
            if let entity = tileMapComponent.tileLayers[layer.id] {
                commands.entity(entity).removeFromWorld(recursively: true)
            }

            let tileParent = commands.spawn("TileRoot<\((layer.id, layer.name))>") {
                RelationshipComponent()
            }

            for (position, tile) in layer.tileCells {
                guard let source = tileSet.sources[tile.sourceId] else {
                    logger.critical("TileSource not found for id: \(tile.sourceId)", metadata: [
                        "layer": .string(layer.id.description),
                        "tileSourceId": .string(tile.sourceId.description)
                    ])
                    continue
                }

                let tileData = source.getTileData(at: tile.atlasCoordinates)
                let position = Vector3(
                    x: Float(position.x) * tileSize.width,
                    y: Float(position.y) * tileSize.height,
                    z: Float(layer.zIndex)
                )

                let tileEntity: Entity
                switch source {
                case let atlasSource as TextureAtlasTileSource:
                    let texture = atlasSource.getTexture(at: tile.atlasCoordinates)

                    tileEntity = Entity {
                        Sprite(
                            texture: AssetHandle(texture),
                            tintColor: tileData.modulateColor,
                            size: tileSize
                        )
                        Transform(position: position)
                    }
                case let entitySource as TileEntityAtlasSource:
                    tileEntity = entitySource.getEntity(at: tile.atlasCoordinates)
                    tileEntity.components += Transform(position: position)
                    tileEntity.components[Sprite.self]?.size = tileSize
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
