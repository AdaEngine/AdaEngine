@_spi(AdaEngine) import AdaEngine
@_spi(Internal) @testable import AdaInput
@testable import AdaUI
import Testing

@testable import AdaEditor

@MainActor
@Suite("Sidebar hover performance", .serialized)
struct EditorSidebarHoverTests {
    init() {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World(name: "SidebarHoverTests")))
        }
    }

    @Test("Hovering a large hierarchy updates the hovered rows without rebuilding the panel", arguments: [1, 128])
    func hierarchyHover(eventsPerFrame: Int) throws {
        var model = EditorSceneModel.default(projectName: "Hover scene")
        for index in 0..<539 { _ = model.addEntity(name: "Entity \(index)", parentID: nil) }
        let document = EditorSceneDocument(
            id: "hover-scene", title: "Main.ascn", relativePath: "Main.ascn", absolutePath: nil,
            content: try model.encodedYAML(), sceneModel: model, isDirty: false,
            loadSummary: .init(entityCount: model.entities.count, warnings: [])
        )
        var selectedID: String?
        let container = UIContainerView(rootView: EditorSceneHierarchySidebar(
            document: document, presentation: .embedded,
            onSelectEntity: { selectedID = $0 }, onToggleEntityExpanded: { _ in }
        ))
        prepare(container)
        let root = container.viewTree.rootNode
        let ids = Array(model.entities.dropFirst().prefix(3).map(\.id))
        let points = try ids.map { id -> Point in
            let row = try #require(root.uiCollectNodes { $0.accessibilityIdentifier == "AdaEditor.SceneHierarchy.Select.\(id)" }.first)
            let frame = row.visualAbsoluteFrame()
            return Point(x: frame.midX, y: frame.midY)
        }
        try checkHover(container, points: points, eventsPerFrame: eventsPerFrame) { index in
            let id = ids[index]
            #expect(!root.uiCollectNodes { $0.accessibilityIdentifier == "AdaEditor.SceneHierarchy.RowState.\(id).hovered" }.isEmpty)
        }
        click(container, at: try #require(points.last))
        #expect(selectedID == ids.last)
    }

    @Test("Hovering a large file tree updates only the hovered rows and preserves opening files", arguments: [1, 128])
    func projectTreeHover(eventsPerFrame: Int) throws {
        let items = (0..<600).map { index in
            EditorProjectSidebarViewModel.Item(
                id: "Scene\(index).ascn", disclosure: "", icon: "", title: "Scene\(index).ascn",
                relativePath: "Scene\(index).ascn", level: 0, isActive: false, isFolder: false, kind: .scene
            )
        }
        let model = EditorProjectSidebarViewModel(items: items, displayMode: .files)
        var openedID: String?
        let container = UIContainerView(rootView: EditorProjectSidebar(
            viewModel: model, projectRootItem: nil, onOpenItem: { openedID = $0.id },
            onOpenRawItem: { _ in }, onNewFile: { _ in }, onImportAssets: {}, onDropFiles: { _ in true },
            onRevealItem: { _ in }, onOpenInDefaultApplication: { _ in }, onOpenInTerminal: { _ in },
            onFindInFolder: { _ in }, onFindInProjectRoot: {}, onCopyPath: { _, _ in }, onDeleteItem: { _ in }
        ))
        prepare(container)
        let root = container.viewTree.rootNode
        let points = try items.prefix(3).map { item -> Point in
            let row = try #require(root.uiCollectNodes { $0.accessibilityIdentifier == "AdaEditor.ProjectTree.\(item.title)" }.first)
            let frame = row.visualAbsoluteFrame()
            return Point(x: frame.midX, y: frame.midY)
        }
        try checkHover(container, points: points, eventsPerFrame: eventsPerFrame) { _ in }
        click(container, at: try #require(points.last))
        #expect(openedID == items[2].id)
    }

    @Test("Hover redraws the changed row while retaining the neighboring row's drawing cache")
    func rowDrawingCache() throws {
        let container = UIContainerView(rootView: VStack(spacing: 0) {
            EditorHoverRow { hovered in
                (hovered ? Color.red : Color.blue).frame(width: 200, height: 30)
            }
            EditorHoverRow { hovered in
                (hovered ? Color.red : Color.blue).frame(width: 200, height: 30)
            }
        }.frame(width: 200, height: 60, alignment: .topLeading))
        prepare(container)
        let before = layerVersions(container)
        #expect(before.count == 2)
        let first = container.viewTree.rootNode.uiCollectNodes { $0 is DrawingGroupViewNode }
        let frame = try #require(first.first).visualAbsoluteFrame()
        let point = Point(x: frame.midX, y: frame.midY)
        container.onMouseEvent(MouseEvent(
            window: .empty, button: .none, mousePosition: point, phase: .changed, modifierKeys: [], time: 0
        ))
        container.update(1.0 / 60.0)
        container.layoutIfNeeded()
        let after = layerVersions(container)
        #expect(Set(before.keys) == Set(after.keys))
        #expect(before.keys.filter { before[$0] != after[$0] }.count == 1)
    }

    private func layerVersions<Content: View>(_ container: UIContainerView<Content>) -> [UInt64: UInt64] {
        let context = UIGraphicsContext()
        container.draw(in: container.bounds, with: context)
        return context.getDrawCommands().reduce(into: [:]) { versions, command in
            if case let .beginLayer(id, version, cacheable) = command, cacheable {
                versions[id] = version
            }
        }
    }

    private func prepare<Content: View>(_ container: UIContainerView<Content>) {
        container.frame = Rect(x: 0, y: 0, width: 320, height: 400)
        container.bounds.size = container.frame.size
        container.layoutIfNeeded()
    }

    private func checkHover<Content: View>(
        _ container: UIContainerView<Content>, points: [Point], eventsPerFrame: Int, verify: (Int) throws -> Void
    ) throws {
        let manager = HoverTestWindowManager()
        let window = UIWindow(frame: container.frame, configuration: .init(frame: container.frame), windowManager: manager)
        window.addSubview(container)
        var input = Input(gameControllerEngine: nil)
        let wasEnabled = UILayoutDebugCounters.isEnabled
        UILayoutDebugCounters.isEnabled = true
        defer { UILayoutDebugCounters.isEnabled = wasEnabled }
        var maximumRebuilds = 0
        let clock = ContinuousClock()
        var maximumDuration = Duration.zero
        if eventsPerFrame > 1 {
            UILayoutDebugCounters.reset()
            let started = clock.now
            for sample in 0..<eventsPerFrame {
                window.sendEvent(MouseEvent(
                    window: window.id, button: .none, mousePosition: points[sample % points.count],
                    phase: .changed, modifierKeys: [], time: 0
                ))
            }
            container.update(1.0 / 60.0)
            container.layoutIfNeeded()
            print("Unbatched sidebar hover: \(UILayoutDebugCounters.snapshot.rebuilds) rebuilds, \(started.duration(to: clock.now))")
        }
        var previousVersions = layerVersions(container)
        for iteration in 0..<12 {
            let index = iteration % points.count
            UILayoutDebugCounters.reset()
            input.removeEvents()
            for sample in 0..<eventsPerFrame {
                let sampleIndex = sample == eventsPerFrame - 1 ? index : sample % points.count
                input.receiveEvent(MouseEvent(
                    window: window.id, button: .none, mousePosition: points[sampleIndex], phase: .changed,
                    modifierKeys: [], time: Float(iteration)
                ))
            }
            input.flushPendingEvents()
            let started = clock.now
            window.sendPendingInput(&input)
            container.update(1.0 / 60.0)
            container.layoutIfNeeded()
            maximumDuration = max(maximumDuration, started.duration(to: clock.now))
            #expect(input.eventsPool.count == eventsPerFrame)
            maximumRebuilds = max(maximumRebuilds, UILayoutDebugCounters.snapshot.rebuilds)
            let versions = layerVersions(container)
            #expect(!versions.isEmpty)
            #expect(versions.keys.filter { previousVersions[$0] != versions[$0] }.count <= 2)
            previousVersions = versions
            try verify(index)
        }
        print("Sidebar hover \(eventsPerFrame) events/frame: maximum \(maximumRebuilds) rebuilds, \(maximumDuration)")
        #expect(maximumRebuilds <= 16)
        UILayoutDebugCounters.reset()
        container.onMouseEvent(MouseEvent(
            window: .empty, button: .none, mousePosition: try #require(points.last), phase: .changed, modifierKeys: [], time: 13
        ))
        container.update(1.0 / 60.0)
        container.layoutIfNeeded()
        #expect(UILayoutDebugCounters.snapshot.rebuilds == 0)
    }

    private func click<Content: View>(_ container: UIContainerView<Content>, at point: Point) {
        for phase in [MouseEvent.Phase.began, .ended] {
            container.onMouseEvent(MouseEvent(
                window: .empty, button: .left, mousePosition: point, phase: phase, modifierKeys: [], time: 14
            ))
        }
    }
}

@MainActor
private final class HoverTestWindowManager: UIWindowManager {
    override func resizeWindow(_: UIWindow, size _: Size) {}
    override func getScreen(for _: UIWindow) -> Screen? { nil }
}
