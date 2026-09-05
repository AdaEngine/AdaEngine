import AdaRender
import AdaECS
import AdaSprite
import AdaTransform
import Math
import Testing
@testable import AdaTilemap

@Suite
@MainActor
struct TileMapTests {
    @Test
    func defaultLayerEditsInvalidateTileMap() throws {
        let tileMap = TileMap()
        let layer = try #require(tileMap.layers.first)

        #expect(layer.tileMap === tileMap)

        tileMap.layers.forEach { $0.updateDidFinish() }
        tileMap.updateDidFinish()

        layer.setCell(at: [0, 0], sourceId: 0, atlasCoordinates: [0, 0])

        #expect(layer.needUpdates)
        #expect(tileMap.needsUpdate)
    }

    @Test
    func replacingTileSetMarksEveryLayerForRebuild() throws {
        let tileMap = TileMap()
        let additionalLayer = tileMap.createLayer()

        tileMap.layers.forEach { $0.updateDidFinish() }
        tileMap.updateDidFinish()

        let replacement = TileSet()
        tileMap.tileSet = replacement

        #expect(tileMap.needsUpdate)
        let allLayersNeedUpdates = tileMap.layers.allSatisfy { layer in
            layer.needUpdates
        }
        #expect(allLayersNeedUpdates)
        #expect(tileMap.layers.allSatisfy { $0.tileSet === replacement })
        #expect(additionalLayer.tileMap === tileMap)
    }

    @Test
    func explicitTileSourceIDsAdvanceAutomaticIDs() {
        let tileSet = TileSet()
        let explicitSource = TileSource()
        explicitSource.id = 0
        let explicitID = tileSet.addTileSource(explicitSource)

        let automaticSource = TileSource()
        let automaticID = tileSet.addTileSource(automaticSource)

        #expect(explicitID == 0)
        #expect(automaticID == 1)
        #expect(tileSet.sources.count == 2)
        #expect(tileSet.sources[explicitID] === explicitSource)
        #expect(tileSet.sources[automaticID] === automaticSource)
    }

    @Test
    func sharedTileMapRendersEachOwnerAndLateConsumer() async throws {
        let world = Self.makeWorld()
        let tileMap = Self.makeTileMap()
        let firstOwner = Self.makeOwner(in: world, tileMap: tileMap, position: [10, 20, 0])
        let secondOwner = Self.makeOwner(in: world, tileMap: tileMap, position: [40, 50, 0])

        await world.runScheduler(.update)

        let firstRoot = try #require(Self.rootID(for: firstOwner))
        let secondRoot = try #require(Self.rootID(for: secondOwner))
        #expect(firstRoot != secondRoot)
        #expect(tileMap.needsUpdate == false)

        await world.runScheduler(.update)
        #expect(Self.rootID(for: firstOwner) == firstRoot)
        #expect(Self.rootID(for: secondOwner) == secondRoot)

        let lateOwner = Self.makeOwner(in: world, tileMap: tileMap, position: [70, 80, 0])
        await world.runScheduler(.update)
        #expect(Self.rootID(for: lateOwner) != nil)
    }

    @Test
    func tileMapEditsRebuildAllSharedOwners() async throws {
        let world = Self.makeWorld()
        let tileMap = Self.makeTileMap()
        let firstOwner = Self.makeOwner(in: world, tileMap: tileMap)
        let secondOwner = Self.makeOwner(in: world, tileMap: tileMap)

        await world.runScheduler(.update)
        let firstRoot = try #require(Self.rootID(for: firstOwner))
        let secondRoot = try #require(Self.rootID(for: secondOwner))

        let layer = try #require(tileMap.layers.first)
        layer.setCell(at: [1, 0], sourceId: 0, atlasCoordinates: [0, 0])
        await world.runScheduler(.update)

        #expect(Self.rootID(for: firstOwner) != firstRoot)
        #expect(Self.rootID(for: secondOwner) != secondRoot)
    }

    @Test
    func tileEntityCellsUseIndependentChildrenUnderOwner() async throws {
        let world = Self.makeWorld()
        let tileMap = Self.makeTileMap(cellCount: 2)
        let template = try #require(tileMap.tileSet.sources[0] as? TileEntityAtlasSource)
        let owner = Self.makeOwner(in: world, tileMap: tileMap)

        await world.runScheduler(.update)

        let root = try #require(Self.root(in: owner))
        #expect(root.children.count == 2)
        #expect(Set(root.children.map { $0.id }).count == 2)
        #expect(root.children.allSatisfy { $0.parent === root })
        #expect(template.getEntity(at: [0, 0]) !== root.children[0])
    }

    @Test
    func tileRootsFollowOwnerTransform() async throws {
        let world = Self.makeWorld()
        let tileMap = Self.makeTileMap(cellCount: 0)
        let layer = try #require(tileMap.layers.first)
        layer.setCell(at: [1, 2], sourceId: 0, atlasCoordinates: [0, 0])
        let owner = Self.makeOwner(
            in: world,
            tileMap: tileMap,
            position: [10, 20, 0],
            scale: [2, 3, 1]
        )

        await world.runScheduler(.update)
        await world.runScheduler(.postUpdate)

        let root = try #require(Self.root(in: owner))
        let child = try #require(root.children.first)
        let localTransform = try #require(child.components[Transform.self])
        let globalTransform = try #require(child.components[GlobalTransform.self])
        #expect(localTransform.position == Vector3(2, 6, 0))
        #expect(globalTransform.getTransform().position == Vector3(14, 38, 0))

        owner.components[Transform.self]?.position = [30, 40, 0]
        await world.runScheduler(.postUpdate)
        let movedGlobalTransform = try #require(child.components[GlobalTransform.self])
        #expect(movedGlobalTransform.getTransform().position == Vector3(34, 58, 0))

        owner.components[Transform.self]?.rotation = Quat(axis: [0, 0, 1], angle: .pi / 2)
        await world.runScheduler(.postUpdate)
        let rotated = try #require(child.components[GlobalTransform.self]).getTransform().position
        #expect(abs(rotated.x - 12) < 0.0001)
        #expect(abs(rotated.y - 44) < 0.0001)
    }

    @Test
    func removingLayerRemovesItsRootFromOwner() async throws {
        let world = Self.makeWorld()
        let tileMap = Self.makeTileMap()
        let removedLayer = tileMap.createLayer()
        removedLayer.setCell(at: [0, 0], sourceId: 0, atlasCoordinates: [0, 0])
        let owner = Self.makeOwner(in: world, tileMap: tileMap)

        await world.runScheduler(.update)
        #expect(owner.children.count == 2)

        tileMap.removeLayer(removedLayer)
        await world.runScheduler(.update)

        #expect(owner.children.count == 1)
        #expect(owner.components[TileMapComponent.self]?.tileLayers[removedLayer.id] == nil)
    }

    @Test
    func disabledLayerStaysDisabledAfterRebuild() async throws {
        let world = Self.makeWorld()
        let tileMap = Self.makeTileMap()
        let layer = try #require(tileMap.layers.first)
        layer.isEnabled = false
        let owner = Self.makeOwner(in: world, tileMap: tileMap)

        await world.runScheduler(.update)
        let firstRoot = try #require(Self.root(in: owner))
        #expect(firstRoot.isActive == false)

        layer.setCell(at: [1, 0], sourceId: 0, atlasCoordinates: [0, 0])
        await world.runScheduler(.update)
        let rebuiltRoot = try #require(Self.root(in: owner))
        #expect(rebuiltRoot.id != firstRoot.id)
        #expect(rebuiltRoot.isActive == false)
        #expect(rebuiltRoot.children.allSatisfy { $0.isActive == false })
    }

    @Test
    func tileSetAndDisplaySizeChangesRebuildTiles() async throws {
        let world = Self.makeWorld()
        let tileMap = Self.makeTileMap(cellCount: 0)
        let initialLayer = try #require(tileMap.layers.first)
        initialLayer.setCell(at: [1, 0], sourceId: 0, atlasCoordinates: [0, 0])
        let owner = Self.makeOwner(in: world, tileMap: tileMap)

        await world.runScheduler(.update)
        let firstRoot = try #require(Self.root(in: owner))
        let replacement = TileSet()
        let source = TileEntityAtlasSource()
        source.createTile(at: [0, 0], for: Entity(name: "replacement") {
            Sprite()
            Transform()
        })
        _ = replacement.addTileSource(source)
        tileMap.tileSet = replacement
        await world.runScheduler(.update)
        let secondRoot = try #require(Self.root(in: owner))
        #expect(secondRoot.id != firstRoot.id)

        let layer = try #require(tileMap.layers.first)
        layer.zIndex = 4
        await world.runScheduler(.update)
        let zIndexedRoot = try #require(Self.root(in: owner))
        let zIndexedChild = try #require(zIndexedRoot.children.first)
        #expect(zIndexedChild.components[Transform.self]?.position.z == 4)

        owner.components[TileMapComponent.self]?.tileDisplaySize = Size(width: 5, height: 7)
        await world.runScheduler(.update)
        let thirdRoot = try #require(Self.root(in: owner))
        let child = try #require(thirdRoot.children.first)
        #expect(child.components[Transform.self]?.position == Vector3(5, 0, 4))
        #expect(child.components[Sprite.self]?.size == Size(width: 5, height: 7))
        #expect(thirdRoot.id != zIndexedRoot.id)
    }

    @Test
    func layerEditRebuildsOnlyThatLayer() async throws {
        let world = Self.makeWorld()
        let tileMap = Self.makeTileMap()
        let changedLayer = try #require(tileMap.layers.first)
        let unchangedLayer = tileMap.createLayer()
        unchangedLayer.setCell(at: [0, 0], sourceId: 0, atlasCoordinates: [0, 0])
        let owner = Self.makeOwner(in: world, tileMap: tileMap)

        await world.runScheduler(.update)
        let initialRoots = try #require(owner.components[TileMapComponent.self]?.tileLayers)
        let initialChangedRoot = try #require(initialRoots[changedLayer.id])
        let initialUnchangedRoot = try #require(initialRoots[unchangedLayer.id])

        changedLayer.setCell(at: [1, 0], sourceId: 0, atlasCoordinates: [0, 0])
        await world.runScheduler(.update)
        let rebuiltRoots = try #require(owner.components[TileMapComponent.self]?.tileLayers)
        #expect(rebuiltRoots[changedLayer.id] != initialChangedRoot)
        #expect(rebuiltRoots[unchangedLayer.id] == initialUnchangedRoot)
    }

    @Test
    func displaySizeChangeRebuildsOnlyThatOwner() async throws {
        let world = Self.makeWorld()
        let tileMap = Self.makeTileMap()
        let firstOwner = Self.makeOwner(in: world, tileMap: tileMap)
        let secondOwner = Self.makeOwner(in: world, tileMap: tileMap)

        await world.runScheduler(.update)
        let firstRoot = try #require(Self.rootID(for: firstOwner))
        let secondRoot = try #require(Self.rootID(for: secondOwner))
        firstOwner.components[TileMapComponent.self]?.tileDisplaySize = Size(width: 7, height: 9)

        await world.runScheduler(.update)

        #expect(Self.rootID(for: firstOwner) != firstRoot)
        #expect(Self.rootID(for: secondOwner) == secondRoot)
    }

    @Test
    func replacingMapWithSameRevisionRebuildsOwner() async throws {
        let world = Self.makeWorld()
        let tileMap = Self.makeTileMap()
        let owner = Self.makeOwner(in: world, tileMap: tileMap)

        await world.runScheduler(.update)
        let firstRoot = try #require(Self.rootID(for: owner))
        let replacement = Self.makeTileMap()
        replacement.layers[0].id = tileMap.layers[0].id
        replacement.layers.forEach { $0.updateDidFinish() }
        replacement.updateDidFinish()
        #expect(replacement.updateRevision == tileMap.updateRevision)
        #expect(replacement.layers[0].updateRevision == tileMap.layers[0].updateRevision)
        owner.components[TileMapComponent.self]?.tileMap = replacement

        await world.runScheduler(.update)

        #expect(Self.rootID(for: owner) != firstRoot)
    }

    @Test
    func removingOwnerRecursivelyRemovesTileRoot() async throws {
        let world = Self.makeWorld()
        let tileMap = Self.makeTileMap(cellCount: 2)
        let owner = Self.makeOwner(in: world, tileMap: tileMap)

        await world.runScheduler(.update)
        let rootID = try #require(Self.rootID(for: owner))
        let root = try #require(world.getEntityByID(rootID))
        let tileIDs = root.children.map(\.id)
        #expect(tileIDs.count == 2)
        owner.removeFromWorld(recursively: true)
        await world.runScheduler(.update)

        #expect(world.getEntityByID(owner.id) == nil)
        #expect(world.getEntityByID(rootID) == nil)
        for tileID in tileIDs {
            #expect(world.getEntityByID(tileID) == nil)
        }
    }

    private static func makeWorld() -> World {
        TileMapComponent.registerComponent()
        TileEntityAtlasSource.registerTileSource()
        RelationshipComponent.registerComponent()
        Transform.registerComponent()
        GlobalTransform.registerComponent()
        Sprite.registerComponent()
        Visibility.registerComponent()
        BoundingComponent.registerComponent()

        let world = World()
        world.addSystem(TileMapSystem.self, on: .update)
        world.addSystem(TransformSystem.self, on: .postUpdate)
        world.addSystem(ChildTransformSystem.self, on: .postUpdate)
        return world
    }

    private static func makeTileMap(cellCount: Int = 1) -> TileMap {
        let tileMap = TileMap()
        let tileSource = TileEntityAtlasSource()
        tileSource.createTile(at: [0, 0], for: Entity(name: "template") {
            Sprite()
            Transform()
        })
        _ = tileMap.tileSet.addTileSource(tileSource)
        let layer = tileMap.layers[0]
        for x in 0..<cellCount {
            layer.setCell(at: [x, 0], sourceId: 0, atlasCoordinates: [0, 0])
        }
        return tileMap
    }

    private static func makeOwner(
        in world: World,
        tileMap: TileMap,
        position: Vector3 = .zero,
        scale: Vector3 = .one
    ) -> Entity {
        world.spawn {
            TileMapComponent(tileMap: tileMap, tileDisplaySize: Size(width: 2, height: 3))
            Transform(scale: scale, position: position)
        }
    }

    private static func rootID(for owner: Entity) -> Entity.ID? {
        owner.components[TileMapComponent.self]?.tileLayers.values.first
    }

    private static func root(in owner: Entity) -> Entity? {
        guard let rootID = rootID(for: owner) else { return nil }
        return owner.world?.getEntityByID(rootID)
    }
}
