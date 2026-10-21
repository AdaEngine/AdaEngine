@_spi(Internal) import AdaApp
import AdaEngine
@_spi(Internal) import AdaPlatform
import Foundation

@main
@MainActor
struct Physics2DDemoMain {
    static func main() async throws {
        if CommandLine.arguments.contains("--validate") {
            try await validate()
            return
        }
        if CommandLine.arguments.contains("--verify") {
            Task { @MainActor in
                do {
                    let path = argument(after: "--proof-directory") ?? "/tmp/ada-physics2d-proof"
                    try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
                    try await verifyWindow(to: path)
                    report("Physics2DDemo verification PASS")
                } catch {
                    report("Physics2DDemo verification FAIL: \(error)")
                }
            }
        }
        try await AppRuntime.run(Physics2DDemoApp())
    }

    private static func argument(after flag: String) -> String? {
        guard let index = CommandLine.arguments.firstIndex(of: flag), CommandLine.arguments.indices.contains(index + 1) else {
            return nil
        }
        return CommandLine.arguments[index + 1]
    }

    private static func validate() async throws {
        for scene in PhysicsDemoScene.allCases {
            let session = PhysicsDemoSession(scene: scene, rendering: false)
            session.scan = false
            let app = AppWorlds(main: World())
            app.addPlugin(MainSchedulerPlugin()).addPlugin(TransformPlugin())
                .addPlugin(Physics2DPlugin(gravity: scene.gravity))
                .addPlugin(PhysicsDemoPlugin(session: session))
            try await app.build()
            app.main.insertResource(FixedTime(deltaTime: 1.0 / 60))
            await app.main.runScheduler(.startup)
            for _ in 0..<240 {
                for scheduler: SchedulerName in [.preUpdate, .fixedPreUpdate, .physicsSync, .physicsStep, .physicsWriteback, .postUpdate] {
                    await app.main.runScheduler(scheduler)
                }
            }
            if scene == .queries {
                guard session.queryEntities.count == 4 else { throw Failure.queries }
                session.querySensors = false
                await app.main.runScheduler(.postUpdate)
                guard session.queryEntities.count == 3 else { throw Failure.queries }
                session.probeMode = .overlap
                await app.main.runScheduler(.postUpdate)
                guard session.queryEntities.count == 1 else { throw Failure.queries }
                session.probeMode = .area
                await app.main.runScheduler(.postUpdate)
                guard session.queryEntities.count == 3 else { throw Failure.queries }
                report("PASS: geometry/query scene · cast / sensor exclusion / exact overlap / area")
            } else if scene == .raycast {
                guard session.lastHits.count == 3, session.lastHits[0].distance < session.lastHits[1].distance else { throw Failure.raycast }
                session.allHits = false
                await app.main.runScheduler(.postUpdate)
                guard session.lastHits.count == 1 else { throw Failure.raycast }
                session.allHits = true
                session.blueOnly = true
                await app.main.runScheduler(.postUpdate)
                guard session.lastHits.count == 2 else { throw Failure.raycast }
                report("PASS: raycast scene · 3 ordered hits / nearest / 2 blue-layer hits")
            } else {
                try requireEvents(session)
                report("PASS: event scene · contacts=\(session.contactBegins)/\(session.contactEnds), sensors=\(session.sensorBegins)/\(session.sensorEnds), impacts=\(session.impacts)")
            }
        }
    }

    private static func waitForSource(_ label: String, excluding previous: SceneViewFrameSource? = nil) async throws -> SceneViewFrameSource {
        for _ in 0..<100 {
            if let source = SceneViewFrameRegistry.latest(label: label), source.frameSequence > 2, source !== previous {
                return source
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        report("No ready source for \(label); labels: \(SceneViewFrameRegistry.sources.map(\.label))")
        throw Failure.sceneUnavailable
    }

    private static func nextFrames(_ source: SceneViewFrameSource, count: Int = 5) async throws -> SceneViewCapturedFrame {
        var frame = try await source.captureFrame(after: source.frameSequence, timeout: .seconds(10))
        for _ in 1..<count {
            frame = try await source.captureFrame(after: frame.sequence, timeout: .seconds(10))
        }
        return frame
    }

    private static func verifyWindow(to directory: String) async throws {
        let raySource = try await waitForSource("Physics2D Raycasts")
        guard let session = raySource.world?.getResource(PhysicsDemoSession.self) else { throw Failure.sceneUnavailable }
        guard let window = Application.shared.windowManager.activeWindow ?? Application.shared.windowManager.windows.values.first?.value,
            let container = window.uiInspectableContainers().first else { throw Failure.sceneUnavailable }
        func tap(_ identifier: String) throws {
            _ = try container.uiTapNode(matching: .accessibilityIdentifier(identifier))
        }
        try tap("physics-demo.scan")
        _ = try await nextFrames(raySource)
        guard !session.scan, session.lastHits.count == 3 else { throw Failure.raycast }
        try tap("physics-demo.mode")
        _ = try await nextFrames(raySource)
        guard !session.allHits, session.lastHits.count == 1 else { throw Failure.raycast }
        try tap("physics-demo.mode")
        try tap("physics-demo.mask")
        _ = try await nextFrames(raySource)
        guard session.blueOnly, session.lastHits.count == 2 else { throw Failure.raycast }
        try tap("physics-demo.mask")
        let rayFrame = try await nextFrames(raySource)
        try write(rayFrame.image, to: directory + "/raycasts.png")
        report("PASS: native raycast buttons · all / nearest / layer mask")
        try tap("physics-demo.events")
        let eventSource = try await waitForSource("Physics2D Events")
        guard let events = eventSource.world?.getResource(PhysicsDemoSession.self) else { throw Failure.sceneUnavailable }
        for _ in 0..<180 {
            _ = try await nextFrames(eventSource, count: 1)
            if events.sensorEnds > 0 && events.contactBegins > 0 && events.contactEnds > 0 && events.impacts > 0 { break }
        }
        try requireEvents(events)
        let eventFrame = try await nextFrames(eventSource)
        try write(eventFrame.image, to: directory + "/events.png")
        let initialImpacts = events.impacts
        try tap("physics-demo.drop")
        var observedDrop = false
        for _ in 0..<20 {
            _ = try await nextFrames(eventSource, count: 1)
            if (events.falling?.components[Transform.self]?.position.y ?? 0) > 2 {
                observedDrop = true
                break
            }
        }
        guard observedDrop else { throw Failure.events }
        for _ in 0..<150 {
            _ = try await nextFrames(eventSource, count: 1)
            if events.impacts > initialImpacts { break }
        }
        guard events.impacts > initialImpacts else { throw Failure.events }
        var verification: [String: Any] = [
            "passed": true, "backend": String(describing: unsafe RenderEngine.shared.type), "raycastAll": 3, "raycastNearest": 1, "raycastBlueMask": 2,
            "contactBegins": events.contactBegins, "contactEnds": events.contactEnds,
            "sensorBegins": events.sensorBegins, "sensorEnds": events.sensorEnds, "impacts": events.impacts,
            "lastImpactSpeed": events.lastImpactSpeed, "sceneReentry": true, "dropButton": true, "rayFrame": rayFrame.sequence, "eventFrame": eventFrame.sequence,
        ]
        try tap("physics-demo.raycasts")
        let rebuiltRay = try await waitForSource("Physics2D Raycasts", excluding: raySource)
        _ = try await nextFrames(rebuiltRay)
        guard let rebuilt = rebuiltRay.world?.getResource(PhysicsDemoSession.self),
            rebuilt.lastHits.count == 3, rebuilt.markers.count == 3 else { throw Failure.raycast }
        try tap("physics-demo.events")
        _ = try await waitForSource("Physics2D Events", excluding: eventSource)
        report("PASS: native events · sensor entry/exit, contact begin/end, impact, re-drop, scene re-entry")
        try tap("physics-demo.queries")
        let queriesSource = try await waitForSource("Physics2D Geometry & queries")
        guard let queries = queriesSource.world?.getResource(PhysicsDemoSession.self) else { throw Failure.sceneUnavailable }
        try tap("physics-demo.query-scan")
        _ = try await nextFrames(queriesSource)
        guard queries.queryEntities.count == 4 else { throw Failure.queries }
        try tap("physics-demo.query-sensors")
        _ = try await nextFrames(queriesSource)
        guard queries.queryEntities.count == 3 else { throw Failure.queries }
        try tap("physics-demo.query-mask")
        _ = try await nextFrames(queriesSource)
        guard queries.queryEntities.count == 2 else { throw Failure.queries }
        try tap("physics-demo.query-order")
        _ = try await nextFrames(queriesSource)
        guard queries.queryEntities.count == 1 else { throw Failure.queries }
        try tap("physics-demo.query-order")
        try tap("physics-demo.query-mask")
        try tap("physics-demo.query-sensors")
        let geometryFrame = try await nextFrames(queriesSource)
        report("Geometry debug \(queries.debugDrawState), options=\(queriesSource.world?.getResource(PhysicsDebugOptions.self)?.rawValue ?? 0)")
        try write(geometryFrame.image, to: directory + "/geometry-cast.png")
        try tap("physics-demo.query-kind")
        _ = try await nextFrames(queriesSource)
        guard queries.queryEntities.count == 1 else { throw Failure.queries }
        try tap("physics-demo.query-kind")
        let areaFrame = try await nextFrames(queriesSource)
        guard queries.queryEntities.count == 4 else { throw Failure.queries }
        try write(areaFrame.image, to: directory + "/geometry-area.png")
        try tap("physics-demo.query-kind")
        try tap("physics-demo.raycasts")
        _ = try await waitForSource("Physics2D Raycasts", excluding: rebuiltRay)
        try tap("physics-demo.queries")
        let rebuiltQueries = try await waitForSource("Physics2D Geometry & queries", excluding: queriesSource)
        _ = try await nextFrames(rebuiltQueries)
        guard queries.queryEntities.count == 4, queries.targets.count == 8 else { throw Failure.queries }
        verification["querySceneReentry"] = true
        verification["geometryQueries"] = true
        report("PASS: native geometry · convex cast / overlap / area / masks / sensors / nearest")
        try JSONSerialization.data(withJSONObject: verification, options: [.prettyPrinted, .sortedKeys])
            .write(to: URL(fileURLWithPath: directory + "/verification.json"), options: .atomic)
    }

    private static func requireEvents(_ session: PhysicsDemoSession) throws {
        guard session.contactBegins > 0, session.contactEnds > 0, session.sensorBegins > 0,
            session.sensorEnds > 0, session.impacts > 0, session.lastImpactSpeed > 0 else { throw Failure.events }
    }

    private static func write(_ image: Image, to path: String) throws {
        guard image.width > 0, image.height > 0, !image.data.isEmpty else { throw Failure.emptyFrame }
        var bytes = Array(image.data)
        if image.format == .bgra8 || image.format == .bgra8_sRGB {
            for index in stride(from: 0, to: bytes.count, by: 4) { bytes.swapAt(index, index + 2) }
        }
        var colors = Set<UInt32>()
        for offset in stride(from: 0, to: bytes.count - 3, by: 64) {
            colors.insert(UInt32(bytes[offset]) << 16 | UInt32(bytes[offset + 1]) << 8 | UInt32(bytes[offset + 2]))
        }
        let png = try PNGWriter().encode(width: image.width, height: image.height, rgba: bytes)
        try png.write(to: URL(fileURLWithPath: path), options: .atomic)
        guard image.width > 200, image.height > 200, colors.count > 3 else { report("Frame \(path) contains \(colors.count) sampled colors"); throw Failure.emptyFrame }
    }

    private static func report(_ message: String) {
        FileHandle.standardOutput.write(Data((message + "\n").utf8))
    }

    private enum Failure: Error {
        case raycast, events, queries, sceneUnavailable, emptyFrame
    }
}
