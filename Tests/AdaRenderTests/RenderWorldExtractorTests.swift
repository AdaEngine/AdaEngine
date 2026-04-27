import Testing
@_spi(Internal) import AdaECS
@_spi(Internal) @testable import AdaRender
import AdaUtils

@Suite("Render World Extractor Tests")
struct RenderWorldExtractorTests {
    @Test("Extraction mirrors primary window id into render world")
    func extractionMirrorsPrimaryWindowIdIntoRenderWorld() async {
        let mainWorld = World(name: "MainWorld")
        let renderWorld = World(name: "RenderWorld")
        let windowId = RID()

        renderWorld.setSchedulers([.extract])
        mainWorld.insertResource(PrimaryWindowId(windowId: windowId))

        await RenderWorldExctractor().exctract(from: mainWorld, to: renderWorld)

        #expect(renderWorld.getResource(PrimaryWindowId.self)?.windowId == windowId)
    }
}
