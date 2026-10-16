@_spi(AdaEngine) import AdaEngine
@_spi(Internal) @testable import AdaUI
import Math
import Testing

@testable import AdaEditor

@MainActor
@Suite("Presented viewport compass")
struct EditorViewportCompassPresentationTests {
    @Test("Rotation updates the compass drawing without rebuilding its host or rulers")
    func compassFollowsPresentedRotation() async throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World(name: "CompassPresentationTests")))
        }
        let viewport = EditorSceneViewportModel()
        viewport.setDisplayMode(.threeD)
        viewport.perspectiveBlend = 1
        viewport.setViewportSize(Size(width: 640, height: 400))
        let presentation = EditorViewportPresentation()
        presentation.refresh(viewportModel: viewport)
        presentation.prepareFrame(viewportModel: viewport, theme: Theme())()
        let builds = CompassHostBuilds()
        let container = UIContainerView(rootView: CompassHost(viewport: viewport, presentation: presentation, builds: builds))
        container.frame = Rect(x: 0, y: 0, width: 640, height: 400)
        container.bounds.size = container.frame.size
        container.layoutIfNeeded()
        let before = compassLines(in: container)
        #expect(before.count == 6)
        let hostBuilds = builds.count
        let rulerRevision = presentation.rulerRevision
        let status = presentation.statusSuffix
        viewport.rotate3D(by: Vector2(80, 35))
        presentation.refresh(viewportModel: viewport)
        let present = presentation.prepareFrame(viewportModel: viewport, theme: Theme())
        #expect(compassLines(in: container) == before)
        present()
        for _ in 0..<3 {
            await Task.yield()
            container.layoutIfNeeded()
            container.update(0)
        }
        #expect(compassLines(in: container) != before)
        #expect(builds.count == hostBuilds)
        #expect(presentation.rulerRevision == rulerRevision)
        #expect(presentation.statusSuffix == status)
    }

    private func compassLines(in container: UIContainerView<CompassHost>) -> [Vector3] {
        let context = UIGraphicsContext()
        container.viewTree.rootNode.draw(with: context)
        context.commitDraw()
        return context.getDrawCommands().compactMap {
            if case let .drawLine(_, end, _, _) = $0 { return end }
            return nil
        }
    }
}

@MainActor
private final class CompassHostBuilds { var count = 0 }

private struct CompassHost: View {
    let viewport: EditorSceneViewportModel
    let presentation: EditorViewportPresentation
    let builds: CompassHostBuilds
    var body: some View {
        builds.count += 1
        return VStack {
            EditorSceneViewportOrientationCompass(viewportModel: viewport, presentation: presentation)
            EditorViewportRulerLayer(viewportModel: viewport, presentation: presentation)
            EditorViewportStatusLabel(presentation: presentation, viewportModel: viewport, warning: nil, entityCount: 0)
        }
    }
}
