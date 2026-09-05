import Testing
@testable import AdaTilemap

@Suite
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
}
