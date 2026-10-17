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
    @Test("Input received during a suspended update survives until the next input phase")
    func inputDuringSuspendedFrame() async throws {
        unsafe RenderEngine.configurations.preferredBackend = .headless
        let gate = ViewportFrameGate()
        let coordinator = SceneViewCoordinator(make: { app in
            app.addPlugin(RenderWorldPlugin()).addPlugin(InputPlugin()).addPlugin(ViewportGatePlugin())
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
        coordinator.receiveInputEvent(MouseEvent(window: RID(), button: .left, mousePosition: [20, 20], phase: .began, modifierKeys: [], time: 1))
        gate.release()
        for _ in 0..<5000 where coordinator.standaloneTickInFlight { await Task.yield() }
        coordinator.tick(1.0 / 60)
        for _ in 0..<5000 where coordinator.standaloneTickInFlight { await Task.yield() }
        #expect(app.main.getResource(Input.self)?.isMouseButtonPressed(.left) == true)
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
