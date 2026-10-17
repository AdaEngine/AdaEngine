@_spi(Internal) import AdaApp
import AdaEngine
import Foundation

@main
@MainActor
struct NavigationDemoMain {
    static func main() async throws {
        if CommandLine.arguments.contains("--validate-script") {
            try await validateScript()
        } else if CommandLine.arguments.contains("--validate") {
            try await validate()
        } else if let index = CommandLine.arguments.firstIndex(of: "--capture"), CommandLine.arguments.indices.contains(index + 1) {
            try await capture(to: CommandLine.arguments[index + 1])
        } else {
            try await AppRuntime.run(NavigationDemoApp())
        }
    }

    private static func validateScript() async throws {
        let app = AppWorlds(main: World())
        app.addPlugin(MainSchedulerPlugin()).addPlugin(Physics3DPlugin()).addPlugin(Navigation3DPlugin())
        try await app.build()
        let script = try NavigationDemoScript.install(in: app)
        let robot = NavigationDemoFixture.installPhysics(in: app.main)
        robot.components[NavigationDemoPatrolComponent.self] = NavigationDemoPatrolComponent()
        robot.components[NavigationTarget3DComponent.self] = NavigationTarget3DComponent()
        app.insertResource(NavigationMap3D(mesh: try await NavigationMesh(data: NavigationDemoFixture.bakedAsset())))
        app.main.insertResource(FixedTime(deltaTime: 1.0 / 60))
        await app.main.runScheduler(.physicsSync)
        for _ in 0..<4800 {
            await app.main.runScheduler(.update)
            await app.main.runScheduler(.physicsStep)
            await app.main.runScheduler(.physicsWriteback)
            if robot.components[NavigationDemoPatrolComponent.self]?.completedGoals == 4 { break }
        }
        guard robot.components[NavigationDemoPatrolComponent.self]?.completedGoals == 4, script.diagnostics.isEmpty else {
            throw DemoFailure.didNotArrive
        }
        print("PASS: NavigationRobot.ada completed four goals through the navigation and physics systems")
    }

    /// Runs the demo's actual bake/file load/target requests/physical movement without a GPU.
    private static func validate() async throws {
        let app = AppWorlds(main: World())
        app.addPlugin(MainSchedulerPlugin()).addPlugin(Physics3DPlugin()).addPlugin(Navigation3DPlugin())
        try await app.build()
        let robot = NavigationDemoFixture.installPhysics(in: app.main)
        let mesh = try await NavigationMesh(data: NavigationDemoFixture.bakedAsset())
        app.insertResource(NavigationMap3D(mesh: mesh))
        app.main.insertResource(FixedTime(deltaTime: 1.0 / 60))
        await app.main.runScheduler(.physicsSync)
        for goal in NavigationDemoFixture.goals {
            robot.components[NavigationTarget3DComponent.self] = NavigationTarget3DComponent(destination: goal)
            for _ in 0..<1200 {
                await app.main.runScheduler(.update)
                await app.main.runScheduler(.physicsStep)
                await app.main.runScheduler(.physicsWriteback)
                if robot.components[NavigationAgent3DComponent.self]?.follower.state == .arrived { break }
            }
            guard robot.components[NavigationAgent3DComponent.self]?.follower.state == .arrived else {
                throw DemoFailure.didNotArrive
            }
            print("PASS: reached \(goal)")
        }
        print("PASS: saved/loaded \(mesh.data.polygonCount) polygons; four goals reached through the physics controller")
    }

    private static func capture(to path: String) async throws {
        weak var capturedApp: AppWorlds?
        let runtime = OffscreenSceneRuntime(label: "NavigationDemo", size: [1100, 760], useSceneCameras: true) { app in
            configureNavigationDemo(&app, session: NavigationDemoSession())
            capturedApp = app
        }
        try await runtime.start(timeout: .seconds(30))
        var completed = false
        defer {
            if !completed, let app = capturedApp {
                let status = app.main.getResource(NavigationDemoSession.self)?.status ?? "missing"
                report("Capture diagnostics: frame=\(runtime.frameSource.frameSequence), cameras=\(runtime.frameSource.activeCameraNames)")
                report("Entities=\(app.main.getEntities().count), status=\(status)")
                if let render = app.getSubworldBuilder(by: .renderWorld) {
                    report("Render entities: \(render.main.getEntities().map(\.name))")
                    if let records = render.getResource(RenderGraphDiagnostics.self)?.recentFrames(limit: 1),
                        let data = try? JSONEncoder().encode(records) { report(String(decoding: data, as: UTF8.self)) }
                }
            }
            runtime.stop()
        }
        var frame = try await runtime.frameSource.captureFrame(after: 0, timeout: .seconds(30))
        try write(frame.image, to: path)
        for _ in 0..<20 {
            frame = try await runtime.frameSource.captureFrame(after: frame.sequence, timeout: .seconds(10))
        }
        try write(frame.image, to: path)
        guard let world = runtime.frameSource.world,
            let cameraEntity = world.getEntities().first(where: { $0.components[Camera.self] != nil }),
            let camera = cameraEntity.components[Camera.self],
            let transform = cameraEntity.components[GlobalTransform.self],
            let session = world.getResource(NavigationDemoSession.self),
            let robotID = session.robot, let robot = world.getEntityByID(robotID) else { throw DemoFailure.sceneUnavailable }
        let probe = Vector3(7.5, 0, 4.5)
        let clip = camera.projection.makeClipView() * transform.matrix.inverse * Vector4(probe, 1)
        guard clip.w.isFinite, clip.w > 0 else { throw DemoFailure.sceneUnavailable }
        let projected = clip.xyz / clip.w
        guard projected.x.isFinite, projected.y.isFinite, projected.z >= 0, projected.z <= 1 else {
            throw DemoFailure.sceneUnavailable
        }
        let size = camera.logicalViewport.rect.size
        let pointer = Vector2((projected.x + 1) * size.width / 2, (1 - projected.y) * size.height / 2)
        let window = world.getResource(PrimaryWindowId.self)?.windowId ?? RID()
        runtime.frameSource.movePointer(to: pointer)
        runtime.frameSource.send(MouseEvent(window: window, button: .left, mousePosition: pointer, phase: .began, modifierKeys: [], time: 1))
        for _ in 0..<10 {
            frame = try await runtime.frameSource.captureFrame(after: frame.sequence, timeout: .seconds(10))
            if let selected = robot.components[NavigationTarget3DComponent.self]?.destination, (selected - probe).length < 0.02 { break }
        }
        runtime.frameSource.send(MouseEvent(window: window, button: .left, mousePosition: pointer, phase: .ended, modifierKeys: [], time: 2))
        for _ in 0..<8 {
            frame = try await runtime.frameSource.captureFrame(after: frame.sequence, timeout: .seconds(10))
        }
        guard let selected = robot.components[NavigationTarget3DComponent.self]?.destination,
            (selected - probe).length < 0.02 else { throw DemoFailure.pickingFailed }
        print("PASS: viewport click selected \(selected)")
        try write(frame.image, to: path)
        completed = true
        print("PASS: captured real GPU frame \(frame.sequence) to \(path)")
    }

    private static func write(_ image: Image, to path: String) throws {
        var bytes = Array(image.data)
        if image.format == .bgra8 || image.format == .bgra8_sRGB {
            for index in stride(from: 0, to: bytes.count, by: 4) { bytes.swapAt(index, index + 2) }
        }
        let png = try PNGWriter().encode(width: image.width, height: image.height, rgba: bytes)
        try png.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    private static func report(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}

private enum DemoFailure: Error {
    case didNotArrive
    case sceneUnavailable
    case pickingFailed
}
