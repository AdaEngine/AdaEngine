@_spi(Internal) import AdaEngine
import Foundation
import Math
import Testing

@testable import AdaEditor

@Suite("Immersive gizmo sizing", .serialized)
@MainActor
struct EditorVRGizmoSizeTests {
    init() {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World()))
        }
    }

    @Test("Immersive handles retain usable screen size and enlarged hit regions at different distances",
          arguments: [Size(width: 1600, height: 1200), Size(width: 4096, height: 4096)], [Float(2), 8])
    func screenSize(size: Size, distance: Float) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let workspace = EditorVRWorkspace(store: EditorProjectStore(storageURL: root.appendingPathComponent("recents.json")))
        try workspace.createStarter(at: root)
        let world = World()
        workspace.attachWorld(world)
        let box = try #require(workspace.document?.sceneModel?.entities.first { $0.name == "Box" })
        workspace.select(box.id)
        let entity = try #require(workspace.viewport.runtimeEntity(for: box.id))
        let transform = try #require(entity.components[Transform.self])
        var projection = PerspectiveProjection(near: 0.1, far: 100, fieldOfView: .degrees(62), aspectRation: size.width / size.height)
        projection.updateView(width: size.width, height: size.height)
        let camera = EditorSceneViewportModel.CameraState(projection: .perspective(projection),
            transform: Transform(position: transform.position - Vector3(0, 0, distance)), renderGraphLabel: .main3D)
        let controller = EditorVRGizmoController()
        for tool in [EditorSceneViewportTool.translate, .scale, .rotate] {
            let gizmo = try #require(controller.definition(in: world, viewport: workspace.viewport, tool: tool, camera: camera, size: size))
            #expect(gizmo.screenLength >= 200)
            #expect(gizmo.screenScale >= 2.5)
            if tool == .rotate {
                let ring = try #require(gizmo.shapes.first { $0.handle == .z })
                let point = try #require(ring.points.first { gizmo.hitTest($0) == .z })
                #expect(Math.sqrt((point - gizmo.screenOrigin).squaredLength) >= 159)
                #expect(gizmo.hitTest(point) == .z)
            } else {
                let endpoint = try #require(gizmo.shapes.first { $0.handle == .x }?.points.last)
                #expect(abs(Math.sqrt((endpoint - gizmo.screenOrigin).squaredLength) - gizmo.screenLength) < gizmo.screenLength * 0.01)
                #expect(gizmo.hitTest(endpoint + Vector2(0, 6 * gizmo.screenScale)) == .x)
                #expect(gizmo.hitTest(endpoint + Vector2(0, 20 * gizmo.screenScale)) == nil)
                #expect(gizmo.hitTest(gizmo.screenOrigin + Vector2(6 * gizmo.screenScale, 0)) == .center)
            }
            var context = UIGraphicsContext()
            gizmo.draw(in: &context, highlighted: nil)
            let widths = context.getDrawCommands().compactMap { command -> Float? in
                if case let .drawPath(_, _, .stroke(_, style)) = command { return style.lineWidth }
                return nil
            }
            #expect(widths.contains { $0 >= 6 })
        }
    }
}
