@_spi(Internal) @testable import AdaApp
@_spi(AdaEngine) import AdaEngine
@_spi(Internal) import AdaInput
@_spi(Internal) import AdaRender
import Foundation
import MCP
import Testing

@testable import AdaEditor

private func steps(_ values: [[String: Value]], extra: [String: Value] = [:]) -> [String: Value] {
    var arguments = extra
    arguments["steps"] = .array(values.map(Value.object))
    return arguments
}

@Suite("Play scenario parsing")
struct EditorPlayScenarioParsingTests {
    @Test("Taps expand to down/up pairs and events are ordered by time")
    func expandsTapsAndOrders() throws {
        let scenario = try EditorPlayScenario.parse(steps([
            ["t": 1.0, "capture": "late"],
            ["t": 0.5, "key": "space", "tap": true, "hold": 0.2],
            ["t": 0.5, "snapshot": "start"],
        ]))
        let times = scenario.events.map(\.time)
        #expect(times == [0.5, 0.5, 0.7, 1.0])
        #expect(scenario.events[0].action == .input(.key(.space, down: true)))
        #expect(scenario.events[1].action == .snapshot(label: "start"))
        #expect(scenario.events[2].action == .input(.key(.space, down: false)))
        #expect(scenario.duration == 1.5)
        #expect(scenario.target == .offscreen)
        #expect(scenario.frameCount == 1)
    }

    @Test("Mouse, pointer and key aliases resolve")
    func resolvesInputKinds() throws {
        let scenario = try EditorPlayScenario.parse(steps([
            ["t": 0, "mouse": "left", "down": true, "x": 10, "y": 20.5],
            ["t": 0.1, "move": ["x": 3, "y": 4]],
            ["t": 0.2, "key": "R", "down": true],
            ["t": 0.3, "key": "up", "down": false],
        ], extra: ["target": "play", "watch": ["entities": ["Bird"], "components": ["Transform"]], "maxDimension": 320]))
        #expect(scenario.events[0].action == .input(.mouse(.left, down: true, x: 10, y: 20.5)))
        #expect(scenario.events[1].action == .input(.pointer(x: 3, y: 4)))
        #expect(scenario.events[2].action == .input(.key(.r, down: true)))
        #expect(scenario.events[3].action == .input(.key(.arrowUp, down: false)))
        #expect(scenario.target == .play)
        #expect(scenario.watch == .init(entities: ["Bird"], components: ["Transform"]))
        #expect(scenario.maxDimension == 320)
    }

    @Test("Invalid steps are rejected with a precise message", arguments: [
        ([["t": 0.0, "key": "nonsense", "down": true]] as [[String: Value]], "steps[0].key"),
        ([["t": 0.0, "key": "space"]] as [[String: Value]], "down"),
        ([["t": 0.0, "key": "space", "down": true, "capture": "x"]] as [[String: Value]], "exactly one"),
        ([["t": -1.0, "capture": "x"]] as [[String: Value]], "steps[0].t"),
        ([["t": 999.0, "capture": "x"]] as [[String: Value]], "steps[0].t"),
        ([["t": 0.0, "key": "space", "tap": true, "hold": 9.0]] as [[String: Value]], "hold"),
        ([["t": 0.0, "mouse": "side", "down": true]] as [[String: Value]], "mouse"),
        ([] as [[String: Value]], "non-empty"),
    ])
    func rejectsInvalidSteps(values: [[String: Value]], message: String) {
        let error = #expect(throws: EditorPlayScenarioError.self) { try EditorPlayScenario.parse(steps(values)) }
        #expect(error?.localizedDescription.contains(message) == true)
    }

    @Test("Limits on frames, events, duration and size are enforced")
    func enforcesLimits() {
        let tooManyFrames = (0...EditorPlayScenario.Limits.maxFrames).map { ["t": .double(Double($0) * 0.1), "capture": .string("f\($0)")] as [String: Value] }
        #expect(throws: EditorPlayScenarioError.self) { try EditorPlayScenario.parse(steps(tooManyFrames)) }

        let tooManyEvents = (0..<(EditorPlayScenario.Limits.maxEvents / 2 + 1)).map { _ in ["t": 0.0, "key": "space", "tap": true] as [String: Value] }
        #expect(throws: EditorPlayScenarioError.self) { try EditorPlayScenario.parse(steps(tooManyEvents)) }

        let tooManySnapshots = (0...EditorPlayScenario.Limits.maxSnapshots).map { ["t": 0.0, "snapshot": .string("s\($0)")] as [String: Value] }
        #expect(throws: EditorPlayScenarioError.self) { try EditorPlayScenario.parse(steps(tooManySnapshots)) }

        #expect(throws: EditorPlayScenarioError.self) { try EditorPlayScenario.parse(steps([["t": 0.0, "capture": "a"]], extra: ["duration": 61])) }
        #expect(throws: EditorPlayScenarioError.self) { try EditorPlayScenario.parse(steps([["t": 5.0, "capture": "a"]], extra: ["duration": 1])) }
        #expect(throws: EditorPlayScenarioError.self) { try EditorPlayScenario.parse(steps([["t": 0.0, "capture": "a"]], extra: ["maxDimension": 99_999])) }
        #expect(throws: EditorPlayScenarioError.self) { try EditorPlayScenario.parse(steps([["t": 0.0, "capture": "a"]], extra: ["width": 100_000])) }
        #expect(throws: EditorPlayScenarioError.self) { try EditorPlayScenario.parse(steps([["t": 0.0, "capture": "a"]], extra: ["target": "cloud"])) }
    }

    @Test("Capture labels become safe file names")
    func sanitizesLabels() throws {
        let scenario = try EditorPlayScenario.parse(steps([["t": 0, "capture": "../etc/passwd x"]]))
        guard case let .capture(label, _) = scenario.events[0].action else { Issue.record("Expected a capture"); return }
        #expect(!label.contains("/") && !label.contains(" ") && !label.contains(".."))
    }
}

@MainActor
private final class FakeScenarioHost: EditorPlayScenarioHost {
    var performed: [(Double, EditorPlayScenario.Input)] = []
    var waited: [Double] = []
    var clock = 0.0
    var failCaptures = false
    var failWaitAt: Double?
    var diagnostics: [String] = []
    var logs: [[String: Any]] = []

    func wait(until time: Double) async throws {
        if let failWaitAt, time >= failWaitAt { throw CancellationError() }
        waited.append(time)
        clock = max(clock, time)
    }

    func perform(_ input: EditorPlayScenario.Input) { performed.append((clock, input)) }

    func captureFrame(camera: String?, maxDimension: Int) async throws -> EditorScenarioFrame {
        if failCaptures { throw SceneViewFrameCaptureError.noGameView(label: "game") }
        return EditorScenarioFrame(image: Image(width: 4, height: 2, color: .red, format: .bgra8), sequence: 7, sourceWidth: 40, sourceHeight: 20, activeCameras: [camera ?? "Camera"])
    }

    func snapshot(watch: EditorPlayScenario.Watch) -> [String: Any] { ["clock": clock, "entities": watch.entities] }
    func drainLogs() -> [[String: Any]] { defer { logs = [] }; return logs }
}

@MainActor
@Suite("Play scenario runner")
struct EditorPlayScenarioRunnerTests {
    private func scenario() throws -> EditorPlayScenario {
        try EditorPlayScenario.parse(steps([
            ["t": 0.5, "key": "space", "tap": true],
            ["t": 0.7, "capture": "after-flap", "camera": "Camera"],
            ["t": 0.8, "snapshot": "state"],
        ], extra: ["watch": ["entities": ["Bird"]]]))
    }

    @Test("Replays input at the scripted times and returns frames, snapshots and logs")
    func replaysScenario() async throws {
        let host = FakeScenarioHost()
        host.logs = [["level": "info", "message": "GAME OVER score=0"], ["level": "error", "message": "boom"]]
        var saved: [String] = []
        let runner = EditorPlayScenarioRunner(host: host) { image, label in
            #expect(image.width == 4)
            saved.append(label)
            return "/tmp/\(label).png"
        }
        let result = await runner.run(try scenario())

        #expect(result["status"] as? String == "completed")
        #expect(host.performed.map(\.0) == [0.5, 0.5 + EditorPlayScenario.Limits.defaultHold])
        #expect(host.performed.count == 2)
        #expect(host.performed.first?.1 == .key(.space, down: true))
        #expect(host.performed.last?.1 == .key(.space, down: false))
        #expect(saved == ["after-flap"])
        let frames = try #require(result["frames"] as? [[String: Any]])
        #expect(frames.first?["path"] as? String == "/tmp/after-flap.png")
        #expect(frames.first?["sourceWidth"] as? Int == 40)
        let snapshots = try #require(result["snapshots"] as? [[String: Any]])
        #expect(snapshots.map { $0["label"] as? String } == ["state", "final"])
        #expect(snapshots.first?["entities"] as? [String] == ["Bird"])
        #expect(result["scriptErrorCount"] as? Int == 1)
        #expect(result["manualChecks"] == nil)
        #expect(host.waited.last == (try scenario()).duration)
    }

    @Test("A failed frame is reported per frame and flagged for manual checking, not fatal")
    func failedFramesBecomeManualChecks() async throws {
        let host = FakeScenarioHost()
        host.failCaptures = true
        let runner = EditorPlayScenarioRunner(host: host) { _, _ in Issue.record("nothing should be saved"); return "" }
        let result = await runner.run(try scenario())

        #expect(result["status"] as? String == "completed")
        let frames = try #require(result["frames"] as? [[String: Any]])
        #expect((frames.first?["error"] as? String)?.contains("Start Play") == true)
        let manual = try #require(result["manualChecks"] as? [String])
        #expect(manual.count == 1)
        #expect((result["verification"] as? [String: Any])?["framesRendered"] as? Bool == false)
        #expect((result["snapshots"] as? [[String: Any]])?.count == 2)
    }

    @Test("Exceeding the wall-clock limit stops the scenario and reports a timeout")
    func timesOut() async throws {
        let host = FakeScenarioHost()
        var current = Date(timeIntervalSince1970: 0)
        var runner = EditorPlayScenarioRunner(host: host) { _, _ in "/tmp/x.png" }
        runner.now = {
            current = current.addingTimeInterval(100)
            return current
        }
        let result = await runner.run(try scenario())
        #expect(result["status"] as? String == "timed_out")
        #expect(host.performed.isEmpty)
        #expect((result["errors"] as? [String])?.first?.contains("wall-clock") == true)
        #expect((result["snapshots"] as? [[String: Any]])?.last?["label"] as? String == "final")
    }

    @Test("Cancellation mid-scenario is reported and still returns the final state")
    func cancellation() async throws {
        let host = FakeScenarioHost()
        host.failWaitAt = 0.7
        let runner = EditorPlayScenarioRunner(host: host) { _, _ in "/tmp/x.png" }
        let result = await runner.run(try scenario())
        #expect(result["status"] as? String == "cancelled")
        #expect(host.performed.count == 2)
        #expect((result["frames"] as? [[String: Any]])?.isEmpty == true)
    }
}

@MainActor
@Suite("Offscreen game host", .serialized)
struct EditorSceneViewScenarioHostTests {
    private func makeRuntime(label: String) -> OffscreenSceneRuntime {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World(name: "EditorSceneViewScenarioHostTests")))
        }
        return OffscreenSceneRuntime(label: label, size: SizeInt(width: 64, height: 64), useSceneCameras: true) { app in
            app.addPlugin(TransformPlugin())
            app.addPlugin(InputPlugin(actions: []))
            var camera = Camera()
            camera.projection = .perspective(PerspectiveProjection())
            app.main.spawn("Camera") { camera; Transform() }
            app.main.spawn("Bird") { Transform(position: [-3, 1.5, 0]) }
        }
    }

    @Test("Input reaches the game world and snapshots read entity components")
    func inputAndSnapshot() async throws {
        let host = try await EditorSceneViewScenarioHost.start(runtime: makeRuntime(label: "game"), logSource: nil, warmUp: .milliseconds(50))
        defer { host.stop() }

        let world = try #require(SceneViewFrameRegistry.latest(label: "game")?.world)
        func keyIsPressed() -> Bool { world.getRefResource(Input.self).wrappedValue.isKeyPressed(.space) }
        // The game world consumes queued input on its next frame.
        func settle(_ expected: Bool) async -> Bool {
            for _ in 0..<100 where keyIsPressed() != expected { try? await Task.sleep(for: .milliseconds(20)) }
            return keyIsPressed() == expected
        }
        host.perform(.key(.space, down: true))
        #expect(await settle(true))
        host.perform(.key(.space, down: false))

        let snapshot = host.snapshot(watch: .init(entities: ["Bird", "Missing"], components: ["Transform"]))
        let entities = try #require(snapshot["entities"] as? [[String: Any]])
        #expect(entities.count == 1)
        #expect(entities.first?["name"] as? String == "Bird")
        let components = try #require(entities.first?["components"] as? [String: String])
        #expect(components["Transform"]?.contains("Position: -3.0, 1.5, 0.0") == true)
        #expect(snapshot["missingEntities"] as? [String] == ["Missing"])
        #expect((snapshot["activeCameras"] as? [String]) == ["Camera"])
    }

    @Test("Game-frame capture fails explicitly when the frame never completes, and for unknown cameras")
    func captureFailures() async throws {
        let host = try await EditorSceneViewScenarioHost.start(runtime: makeRuntime(label: "game"), logSource: nil, warmUp: .milliseconds(50))
        defer { host.stop() }

        await #expect(throws: SceneViewFrameCaptureError.self) {
            _ = try await host.captureFrame(camera: "NoSuchCamera", maxDimension: 256)
        }
        await #expect(throws: SceneViewFrameCaptureError.self) {
            _ = try await EditorGameFrameCapture.mcpCaptureOverride(AppWorlds(main: World()), nil, "NoSuchCamera", true, false)
        }
    }
}

@MainActor
@Suite("Game frame capture tools")
struct EditorGameFrameCaptureTests {
    @Test("editor.play.capture reports that no game is running")
    func noGameIsAnExplicitError() async {
        let error = await #expect(throws: SceneViewFrameCaptureError.self) {
            _ = try await EditorGameFrameCapture.captureTool(projectURL: FileManager.default.temporaryDirectory, cameraName: nil, maxDimension: nil)
        }
        #expect(error?.localizedDescription.contains("Start Play") == true)
    }

    @Test("PNG captures are written under the project workspace and pruned")
    func writesAndPrunes() throws {
        let project = FileManager.default.temporaryDirectory.appendingPathComponent("capture-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: project) }
        let directory = EditorGameFrameCapture.capturesDirectory(projectURL: project)
        #expect(directory.path.contains("/.ada/workspace/agent-captures"))
        let image = Image(width: 2, height: 2, color: .white, format: .bgra8)
        for index in 0..<5 {
            let url = try EditorGameFrameCapture.write(image, to: directory, name: "t\(index)")
            #expect(url.pathExtension == "png")
        }
        EditorGameFrameCapture.prune(directory, keeping: 2)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).count == 2)
    }
}

/// Opt-in: plays a real external AdaScript game (for example a side-view Flappy Bird) through the offscreen host.
@MainActor
@Suite("Offscreen scenario on a real project", .serialized)
struct EditorScenarioProjectIntegrationTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ADA_SCENARIO_PROJECT"] != nil))
    func flapRaisesTheBird() async throws {
        let directory = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["ADA_SCENARIO_PROJECT"]))
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World(name: "EditorScenarioProjectIntegrationTests")))
        }
        GLTFLoaderResolver.shared.setLoader(NativeGLTFLoader())
        EditorComponentRegistry.registerBuiltIns()
        let project = try ProjectSystem.loadProject(at: directory)
        let artifact = try EditorAdaScriptProjectBuilder().prepare(project: project, at: directory)
        let host = try await EditorSceneViewScenarioHost.startOffscreen(artifact: artifact, size: SizeInt(width: 320, height: 180), warmUp: false)
        defer { host.stop() }
        let scenario = try EditorPlayScenario.parse(steps([
            ["t": 0.2, "snapshot": "before"],
            ["t": 0.3, "key": "space", "tap": true],
            ["t": 1.2, "snapshot": "after-flap"],
        ], extra: ["watch": ["entities": ["Bird"], "components": ["Transform"]], "warmup": false]))
        let result = await EditorPlayScenarioRunner(host: host) { _, _ in "" }.run(scenario)
        let snapshots = try #require(result["snapshots"] as? [[String: Any]])
        #expect(snapshots.map { $0["label"] as? String } == ["before", "after-flap", "final"])
        #expect(result["status"] as? String == "completed")
        #expect((result["scriptErrorCount"] as? Int) == 0)
        // The game world must advance while the scenario runs.
        let elapsed = snapshots.compactMap { $0["worldElapsedSeconds"] as? Double }
        #expect(elapsed.count == 3 && elapsed[2] > elapsed[0])
    }
}
