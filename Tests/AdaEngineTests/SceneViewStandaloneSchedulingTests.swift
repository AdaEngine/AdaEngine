@_spi(Internal) import AdaApp
import AdaECS
import AdaInput
@_spi(Internal) import AdaRender
import AdaTransform
import Math
import Testing
@testable import AdaEngine

@MainActor
@Suite("Standalone viewport scheduling", .serialized)
struct SceneViewStandaloneSchedulingTests {
    @Test("Content updates observe parsed input once in standalone and hosted worlds", arguments: [false, true])
    func contentUpdateReceivesInput(hosted: Bool) async throws {
        unsafe RenderEngine.configurations.preferredBackend = .headless
        let previousHost = AppWorldsSession.current
        let host = AppWorlds(main: World(name: "Viewport host"))
        MainSchedulerPlugin().setup(in: host)
        try await host.build()
        if hosted { AppWorldsSession.current = host }
        defer { AppWorldsSession.current = previousHost }

        var observedFrames: [[RID]] = []
        var observedParsedState = false
        let coordinator = SceneViewCoordinator(make: { app in
            app.addPlugin(RenderWorldPlugin()).addPlugin(InputPlugin(actions: []))
        }, updateContent: { world, _ in
            guard let input = world.getResource(Input.self) else {
                return
            }
            observedFrames.append(input.getInputEvents().map(\.id))
            if !input.getInputEvents().isEmpty {
                observedParsedState = input.isKeyPressed(.space) && input.isMouseButtonPressed(.right)
            }
        }, joinsHostSession: hosted)
        defer { coordinator.shutdown() }
        coordinator.bootstrapIfNeeded()
        for _ in 0..<5000 where coordinator.appWorlds == nil { await Task.yield() }
        let app = try #require(coordinator.appWorlds)
        coordinator.updateSize([64, 64], scaleFactor: 1)

        let window = RID()
        let mouseDown = MouseEvent(window: window, button: .right, mousePosition: [20, 20], phase: .began, modifierKeys: [], time: 1)
        let mouseDrag = MouseEvent(window: window, button: .right, mousePosition: [30, 20], phase: .changed, modifierKeys: [], time: 2)
        let key = KeyEvent(window: window, keyCode: .space, modifiers: [], status: .down, time: 3, isRepeated: false)
        let wheel = MouseEvent(window: window, button: .scrollWheel, scrollDelta: [0, 1], mousePosition: [30, 20], phase: .changed, modifierKeys: [], time: 4)
        coordinator.receiveInputEvent(mouseDown)
        coordinator.receiveInputEvent(mouseDrag)
        coordinator.receiveInputEvent(key)
        coordinator.receiveInputEvent(wheel)
        #expect(observedFrames.isEmpty)

        coordinator.tick(1.0 / 60)
        if hosted {
            #expect(observedFrames.isEmpty)
            try await host.update()
        } else {
            for _ in 0..<5000 where coordinator.standaloneTickInFlight { await Task.yield() }
        }
        #expect(observedFrames == [[mouseDown.id, mouseDrag.id, key.id, wheel.id]])
        #expect(observedParsedState)
        #expect(app.main.getResource(Input.self)?.getInputEvents().isEmpty == true)

        coordinator.tick(1.0 / 60)
        if hosted {
            try await host.update()
        } else {
            for _ in 0..<5000 where coordinator.standaloneTickInFlight { await Task.yield() }
        }
        #expect(observedFrames == [[mouseDown.id, mouseDrag.id, key.id, wheel.id], []])
    }

    @Test("Input-driven projection changes reach camera preparation in the same frame")
    func inputUpdatesCameraProjectionBeforePreparation() async throws {
        unsafe RenderEngine.configurations.preferredBackend = .headless
        var changedProjection = false
        let coordinator = SceneViewCoordinator(make: { app in
            app.addPlugin(TransformPlugin()).addPlugin(RenderWorldPlugin())
                .addPlugin(CameraPlugin()).addPlugin(InputPlugin(actions: []))
        }, updateContent: { world, _ in
            guard world.getResource(Input.self)?.getInputEvents().isEmpty == false,
                let entity = world.getEntities().first(where: { $0.name == "SceneView_Camera" }),
                var camera = entity.components[Camera.self] else {
                return
            }
            camera.projection = .perspective(PerspectiveProjection())
            entity.components += camera
            changedProjection = true
        }, joinsHostSession: false)
        defer { coordinator.shutdown() }
        coordinator.bootstrapIfNeeded()
        for _ in 0..<5000 where coordinator.appWorlds == nil { await Task.yield() }
        let app = try #require(coordinator.appWorlds)
        coordinator.updateSize([64, 64], scaleFactor: 1)
        coordinator.tick(1.0 / 60)
        for _ in 0..<5000 where coordinator.standaloneTickInFlight { await Task.yield() }
        let entity = try #require(app.main.getEntities().first { $0.name == "SceneView_Camera" })
        let previousProjection = try #require(entity.components[Camera.self]).computedData.projectionMatrix

        coordinator.receiveInputEvent(MouseEvent(
            window: RID(),
            button: .scrollWheel,
            scrollDelta: [0, 1],
            mousePosition: [20, 20],
            phase: .changed,
            modifierKeys: [],
            time: 1
        ))
        coordinator.tick(1.0 / 60)
        for _ in 0..<5000 where coordinator.standaloneTickInFlight { await Task.yield() }
        let camera = try #require(entity.components[Camera.self])
        #expect(changedProjection)
        #expect(camera.computedData.projectionMatrix != previousProjection)
        #expect(camera.computedData.projectionMatrix == camera.projection.makeClipView())
    }

    @Test("Input received during a suspended update survives until the next input phase")
    func inputDuringSuspendedFrame() async throws {
        unsafe RenderEngine.configurations.preferredBackend = .headless
        let gate = ViewportFrameGate()
        var observedEvents: [RID] = []
        let coordinator = SceneViewCoordinator(make: { app in
            app.addPlugin(RenderWorldPlugin()).addPlugin(InputPlugin()).addPlugin(ViewportGatePlugin())
            app.insertResource(gate)
        }, updateContent: { world, _ in
            observedEvents.append(contentsOf: world.getResource(Input.self)?.getInputEvents().map(\.id) ?? [])
        }, joinsHostSession: false)
        defer { gate.release(); coordinator.shutdown() }
        coordinator.bootstrapIfNeeded()
        for _ in 0..<5000 where coordinator.appWorlds == nil { await Task.yield() }
        let app = try #require(coordinator.appWorlds)
        coordinator.updateSize([64, 64], scaleFactor: 1)
        coordinator.tick(1.0 / 60)
        for _ in 0..<5000 where !gate.entered { await Task.yield() }
        #expect(gate.entered)
        let event = MouseEvent(window: RID(), button: .left, mousePosition: [20, 20], phase: .began, modifierKeys: [], time: 1)
        coordinator.receiveInputEvent(event)
        gate.release()
        for _ in 0..<5000 where coordinator.standaloneTickInFlight { await Task.yield() }
        #expect(observedEvents.isEmpty)
        coordinator.tick(1.0 / 60)
        for _ in 0..<5000 where coordinator.standaloneTickInFlight { await Task.yield() }
        #expect(app.main.getResource(Input.self)?.isMouseButtonPressed(.left) == true)
        #expect(observedEvents == [event.id])
        coordinator.tick(1.0 / 60)
        for _ in 0..<5000 where coordinator.standaloneTickInFlight { await Task.yield() }
        #expect(observedEvents == [event.id])
    }

    @Test("An in-flight standalone frame retains its target while UI ticks continue")
    func slowFrameRetainsTarget() async throws {
        unsafe RenderEngine.configurations.preferredBackend = .headless
        let gate = ViewportFrameGate()
        let coordinator = SceneViewCoordinator(useSceneCameras: true, make: { app in
            app.addPlugin(TransformPlugin()).addPlugin(RenderWorldPlugin()).addPlugin(CameraPlugin())
                .addPlugin(ViewportGatePlugin())
            app.insertResource(gate)
            app.main.spawn("Camera") { Camera(); Transform() }
        }, updateContent: { _, _ in })
        defer {
            gate.release()
            coordinator.shutdown()
        }
        coordinator.bootstrapIfNeeded()
        for _ in 0..<5000 where coordinator.appWorlds == nil { await Task.yield() }
        let app = try #require(coordinator.appWorlds)
        coordinator.updateSize([64, 64], scaleFactor: 1)
        coordinator.tick(1.0 / 60)
        for _ in 0..<5000 where !gate.entered { await Task.yield() }
        #expect(gate.entered)
        let camera = try #require(app.main.getEntities().first { $0.components[Camera.self] != nil })
        for _ in 0..<12 { coordinator.tick(1.0 / 60) }
        let value = try #require(camera.components[Camera.self])
        guard case .texture = value.renderTarget else {
            Issue.record("The viewport exhausted its pool by preparing targets without submitting frames")
            return
        }
    }

    @Test("A camera created during startup does not leave an unrendered frame in the display queue")
    func lateCameraCanPresent() async throws {
        unsafe RenderEngine.configurations.preferredBackend = .headless
        let gate = ViewportFrameGate()
        let coordinator = SceneViewCoordinator(useSceneCameras: true, make: { app in
            app.addPlugin(RenderWorldPlugin()).addPlugin(ViewportGatePlugin())
            app.insertResource(gate)
        }, updateContent: { _, _ in })
        defer { gate.release(); coordinator.shutdown() }
        coordinator.bootstrapIfNeeded()
        for _ in 0..<5000 where coordinator.appWorlds == nil { await Task.yield() }
        let app = try #require(coordinator.appWorlds)
        coordinator.updateSize([64, 64], scaleFactor: 1)
        coordinator.tick(1.0 / 60)
        for _ in 0..<5000 where !gate.entered { await Task.yield() }
        #expect(gate.entered)
        let entity = app.main.spawn("Late camera") { Camera(); Transform() }
        gate.release()
        for _ in 0..<5000 where coordinator.standaloneTickInFlight { await Task.yield() }
        coordinator.tick(1.0 / 60)
        for _ in 0..<5000 where coordinator.standaloneTickInFlight { await Task.yield() }
        let camera = try #require(entity.components[Camera.self])
        guard case let .texture(handle) = camera.renderTarget else {
            Issue.record("The late camera must receive an offscreen render target")
            return
        }
        let texture = try #require(handle.asset)
        texture.notifyRenderCompleted()
        for _ in 0..<50 { await Task.yield() }
        coordinator.tick(1.0 / 60)
        #expect(coordinator.completedFrameCount == 1)
    }
}

@MainActor
private final class ViewportFrameGate: Resource {
    var entered = false
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        guard !entered else { return }
        entered = true
        await withCheckedContinuation { continuation = $0 }
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}

private struct ViewportGatePlugin: Plugin {
    func setup(in app: AppWorlds) { app.addSystem(ViewportGateSystem.self, on: .update) }
}

@PlainSystem
struct ViewportGateSystem {
    @Res<ViewportFrameGate> private var gate
    init(world _: World) {}
    @MainActor func update(context _: UpdateContext) async { await gate.wait() }
}
