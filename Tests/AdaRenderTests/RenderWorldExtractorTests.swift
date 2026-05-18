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

    @Test("Explicit primary window id resolves to primary surface")
    func explicitPrimaryWindowIdResolvesToPrimarySurface() {
        let windowId = RID()
        var surfaces = WindowSurfaces(windows: [:])
        surfaces.windows[.primary] = WindowSurface(swapchain: nil, currentDrawable: nil)

        let resolvedSurface = resolveWindowSurface(
            for: .windowId(windowId),
            in: surfaces,
            primaryWindow: PrimaryWindowId(windowId: windowId)
        )

        #expect(resolvedSurface != nil)
    }

    @Test("Unregistered non-primary window id has no surface")
    func unregisteredNonPrimaryWindowIdHasNoSurface() {
        var surfaces = WindowSurfaces(windows: [:])
        surfaces.windows[.primary] = WindowSurface(swapchain: nil, currentDrawable: nil)

        let resolvedSurface = resolveWindowSurface(
            for: .windowId(RID()),
            in: surfaces,
            primaryWindow: PrimaryWindowId(windowId: RID())
        )

        #expect(resolvedSurface == nil)
    }
}
