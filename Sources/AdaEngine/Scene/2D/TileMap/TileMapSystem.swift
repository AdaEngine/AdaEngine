//
//  TileMapSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/5/24.
//

import AdaECS
import Logging

// FIXME: a lot of sprites drop fps.
@System(dependencies: [
    .after(VisibilitySystem.self)
])
public struct TileMapSystem: Sendable {
    
    let logger = Logger(label: "tilemap")

    @Query<Entity, Ref<TileMapComponent>, Transform>
    private var tileMap

    public init(world: World) { }

    public func update(context: UpdateContext) {
        let physicsWorld = context.world.getResource(Physics2DWorldComponent.self)?.world

        for (entity, tileMapComponent, transform) in tileMap {
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
                    tileEntity.components += SpriteComponent(texture: AssetHandle(texture), tintColor: tileData.modulateColor)
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
//                        shapes: tileData.physicsBody?.shapes ?? [.generateBox()], // Use physicsBody shapes or default
//                        filter: layer.collisionFilter // Apply collisionFilter from the layer
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
