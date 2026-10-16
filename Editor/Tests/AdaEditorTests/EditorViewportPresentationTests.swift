@_spi(AdaEngine) import AdaEngine
@_spi(Internal) @testable import AdaUI
import Math
import Testing

@testable import AdaEditor

@MainActor
@Suite("Viewport presentation invalidation")
struct EditorViewportPresentationTests {
    @Test("Camera changes refresh rulers and status without rebuilding their host")
    func cameraChangesStayLocal() async throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World(name: "ViewportPresentationTests")))
        }
        let presentation = EditorViewportPresentation()
        let viewport = EditorSceneViewportModel()
        let builds = HostBuildCounter()
        let host = PresentationHost(presentation: presentation, viewport: viewport, builds: builds)
        let container = UIContainerView(rootView: host)
        container.frame = Rect(x: 0, y: 0, width: 640, height: 400)
        container.bounds.size = container.frame.size
        container.layoutIfNeeded()
        let initialBuilds = builds.count
        let initialGeometryBuilds = builds.geometryCount
        let initialLabels = labels(in: container)
        #expect(initialLabels.contains("Loaded 1 entities · \(viewport.statusSuffix)"))

        viewport.twoDZoom = 75
        viewport.twoDCenter = Vector2(3, 2)
        host.requestRedraw()
        for _ in 0..<3 {
            await Task.yield()
            container.layoutIfNeeded()
            container.update(0)
        }
        let updatedLabels = labels(in: container)
        #expect(builds.count == initialBuilds)
        #expect(builds.geometryCount == initialGeometryBuilds)
        #expect(updatedLabels.contains("Loaded 1 entities · \(viewport.statusSuffix)"))
        #expect(updatedLabels != initialLabels)
    }

    @Test("Viewport annotation commands persist until navigation changes them")
    func annotationDrawingIsRetained() async throws {
        let presentation = EditorViewportPresentation()
        let viewport = EditorSceneViewportModel()
        let container = UIContainerView(rootView: EditorViewportDrawingLayer(
            viewportModel: viewport, presentation: presentation, kind: .grid
        ))
        container.frame = Rect(x: 0, y: 0, width: 640, height: 400)
        container.bounds.size = container.frame.size
        container.layoutIfNeeded()

        func layerRevision() throws -> UInt64 {
            let context = UIGraphicsContext()
            container.viewTree.rootNode.draw(with: context)
            context.commitDraw()
            return try #require(context.getDrawCommands().compactMap { command -> UInt64? in
                if case let .beginLayer(_, version, cacheable) = command, cacheable { return version }
                return nil
            }.first)
        }

        let initial = try layerRevision()
        #expect(try layerRevision() == initial)
        viewport.twoDZoom = 75
        presentation.revision &+= 1
        for _ in 0..<3 {
            await Task.yield()
            container.layoutIfNeeded()
            container.update(0)
        }
        let navigated = try layerRevision()
        #expect(navigated > initial)
        #expect(try layerRevision() == navigated)
    }

    private func labels(in container: UIContainerView<PresentationHost>) -> Set<String> {
        Set(container.viewTree.rootNode.uiCollectNodes { $0.content is Text }
            .compactMap { ($0.content as? Text)?.plainText })
    }
}

@MainActor
private final class HostBuildCounter {
    var count = 0
    var geometryCount = 0
}

private struct PresentationHost: View {
    @State var presentation: EditorViewportPresentation
    let viewport: EditorSceneViewportModel
    let builds: HostBuildCounter

    init(presentation: EditorViewportPresentation, viewport: EditorSceneViewportModel, builds: HostBuildCounter) {
        self._presentation = State(wrappedValue: presentation)
        self.viewport = viewport
        self.builds = builds
    }

    func requestRedraw() { presentation.revision &+= 1 }

    var body: some View {
        builds.count += 1
        return GeometryReader { _ in
            builds.geometryCount += 1
            return VStack {
                EditorViewportRulerLayer(viewportModel: viewport, presentation: presentation)
                EditorViewportStatusLabel(presentation: presentation, viewportModel: viewport, warning: nil, entityCount: 1)
            }
        }
    }
}
