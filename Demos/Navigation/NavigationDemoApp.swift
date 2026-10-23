import AdaEngine
import Foundation
import Observation

@MainActor
@Observable
final class NavigationDemoSession: Resource {
    var status = "Готовим площадку…"
    var showNavigation = true
    var rebakeRequested = false
    var nextGoalRequested = false
    var resetRequested = false
    var patrolRequested = false
    var script: AdaScriptPlugin?
    var triangles: [Vector3] = []
    var robot: Entity.ID?
    var goalIndex = 0
    var wasMouseDown = false

    func setStatus(_ value: String) {
        if status != value { status = value }
    }
}

struct NavigationDemoApp: App {
    var body: some AppScene {
        WindowGroup { NavigationDemoView() }
            .window(with: UIWindow.Configuration(title: "AdaEngine · Navigation playground", frame: Rect(x: 80, y: 60, width: 1100, height: 800)))
    }
}

private struct NavigationDemoView: View {
    @State private var session = NavigationDemoSession()

    var body: some View {
        VStack(spacing: 12) {
            Text("Проложи путь для робота").font(.system(size: 24))
            Text("Нажми на пол — робот найдёт дорогу вокруг препятствий.")
            HStack(spacing: 18) {
                Button("Другая цель") { session.nextGoalRequested = true }
                Button(session.showNavigation ? "Скрыть сетку" : "Показать сетку") { session.showNavigation.toggle() }
                Button("В начало") { session.resetRequested = true }
                Button("Запечь заново") { session.rebakeRequested = true }
                Button("Патруль AdaScript") { session.patrolRequested = true }
            }
            Text(session.status)
            SceneView(useSceneCameras: true, make: { app in
                configureNavigationDemo(&app, session: session)
            }, updateContent: { _, _ in })
            .frameCaptureLabel("NavigationDemo")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
        .background(Color(0.06, 0.08, 0.13, 1))
        .foregroundColor(.white)
    }
}

@MainActor
func configureNavigationDemo(_ app: inout AppWorlds, session: NavigationDemoSession) {
    app.addPlugin(TransformPlugin()).addPlugin(InputPlugin()).addPlugin(RenderWorldPlugin())
        .addPlugin(CameraPlugin()).addPlugin(AssetsPlugin()).addPlugin(VisibilityPlugin())
        .addPlugin(ScenePlugin()).addPlugin(Core3DPlugin(includes2D: false)).addPlugin(UpscalePlugin())
        .addPlugin(Physics3DPlugin()).addPlugin(Navigation3DPlugin()).addPlugin(NavigationDemoPlugin())
    app.insertResource(session)
}

/// SceneView installs its schedulers after make(); register systems when plugins are built.
private struct NavigationDemoPlugin: Plugin {
    func setup(in app: AppWorlds) {
        app.addSystem(NavigationDemoStartupSystem.self, on: .startup)
        app.addSystem(NavigationDemoControlsSystem.self, on: .update)
        app.addSystem(NavigationDemoOverlaySystem.self, on: .postUpdate)
        do {
            app.main.getResource(NavigationDemoSession.self)?.script = try NavigationDemoScript.install(in: app)
        } catch {
            app.main.getResource(NavigationDemoSession.self)?.setStatus("Ошибка AdaScript: \(error)")
        }
        if CommandLine.arguments.contains("--capture") {
            app.getSubworldBuilder(by: .renderWorld)?.getResource(RenderGraphDiagnostics.self)?.configure(isEnabled: true)
        }
    }
}

@System
@MainActor
func NavigationDemoStartup(_ context: WorldUpdateContext, _ session: Res<NavigationDemoSession>) async {
    let robot = NavigationDemoFixture.installPhysics(in: context.world)
    session.wrappedValue.robot = robot.id
    robot.components[NavigationDemoPatrolComponent.self] = NavigationDemoPatrolComponent()
    robot.components[NavigationTarget3DComponent.self] = NavigationTarget3DComponent()
    NavigationDemoFixture.installGraphics(in: context.world, robot: robot)
    do {
        let mesh = try await NavigationMesh(data: NavigationDemoFixture.bakedAsset())
        context.world.insertResource(NavigationMap3D(mesh: mesh))
        session.wrappedValue.triangles = try await mesh.debugTriangles()
    } catch {
        session.wrappedValue.status = "Не удалось построить сетку: \(error)"
    }
}

@PlainSystem(dependencies: [.before(NavigationPathRequest3DSystem.self)])
struct NavigationDemoControlsSystem {
    @Res<NavigationDemoSession> private var session
    @Res<Input> private var input
    @Query<Camera, GlobalTransform> private var cameras
    // Reset/picking use the robot's stable ID; declare those component writes to the scheduler.
    @Query<Ref<Transform>, Ref<NavigationAgent3DComponent>, Ref<NavigationTarget3DComponent>, Ref<CharacterController3DComponent>, Ref<NavigationDemoPatrolComponent>>
    private var robotAccess

    init(world _: World) {}

    @MainActor
    func update(context: UpdateContext) async {
        let state = session
        _ = robotAccess
        guard let id = state.robot, let robot = context.world.getEntityByID(id) else { return }
        if state.resetRequested {
            robot.components[NavigationDemoPatrolComponent.self] = NavigationDemoPatrolComponent(enabled: false)
            state.resetRequested = false
            robot.components[Transform.self] = Transform(position: NavigationDemoFixture.start)
            var controller = robot.components[CharacterController3DComponent.self] ?? CharacterController3DComponent()
            controller.resetMotion = true
            robot.components[CharacterController3DComponent.self] = controller
            // Invalidate the pending request even when returning to the same goal.
            robot.components[NavigationAgent3DComponent.self] = NavigationAgent3DComponent()
        }
        if state.nextGoalRequested {
            robot.components[NavigationDemoPatrolComponent.self] = NavigationDemoPatrolComponent(enabled: false)
            state.nextGoalRequested = false
            state.goalIndex = (state.goalIndex + 1) % NavigationDemoFixture.goals.count
            robot.components[NavigationTarget3DComponent.self] = NavigationTarget3DComponent(destination: NavigationDemoFixture.goals[state.goalIndex])
        }
        let down = input.isMouseButtonPressed(.left)
        if down && !state.wasMouseDown, let (camera, transform) = cameras.first,
            let ray = camera.viewportToWorld(
                cameraGlobalTransform: transform.matrix,
                point: Vector2(input.getMousePosition().x, camera.logicalViewport.rect.size.height - input.getMousePosition().y)
            ),
            abs(ray.direction.y) > 0.0001 {
            let distance = -ray.origin.y / ray.direction.y
            let point = ray.origin + ray.direction * distance
            if distance > 0, abs(point.x) < 10, abs(point.z) < 7 {
                robot.components[NavigationDemoPatrolComponent.self] = NavigationDemoPatrolComponent(enabled: false)
                robot.components[NavigationTarget3DComponent.self] = NavigationTarget3DComponent(destination: [point.x, 0, point.z])
            }
        }
        state.wasMouseDown = down
        if state.patrolRequested {
            state.patrolRequested = false
            robot.components[NavigationDemoPatrolComponent.self] = NavigationDemoPatrolComponent()
            robot.components[NavigationTarget3DComponent.self] = NavigationTarget3DComponent()
        }
        if state.rebakeRequested {
            state.rebakeRequested = false
            state.status = "Запекаем площадку…"
            do {
                let mesh = try await NavigationMesh(data: NavigationDemoFixture.bakedAsset())
                context.world.insertResource(NavigationMap3D(mesh: mesh))
                state.triangles = try await mesh.debugTriangles()
            } catch {
                state.status = "Ошибка запекания: \(error)"
            }
        }
    }
}

@System
@MainActor
func NavigationDemoOverlay(
    _ session: Res<NavigationDemoSession>,
    _ agents: Query<NavigationAgent3DComponent, NavigationTarget3DComponent, Transform>,
    _ draw: Res<DebugDraw3D>
) {
    let state = session.wrappedValue
    if state.showNavigation {
        let triangles = state.triangles
        for offset in stride(from: 0, to: triangles.count, by: 3) {
            draw.wrappedValue.polyline(Array(triangles[offset..<(offset + 3)]).map { $0 + Vector3(0, 0.06, 0) }, closed: true, color: Color(0.15, 0.85, 0.7, 1))
        }
    }
    agents.forEach { agent, target, transform in
        if let path = agent.follower.path {
            draw.wrappedValue.polyline(path.points.map { $0 + Vector3(0, 0.16, 0) }, color: .yellow, depthTested: false)
        }
        if let destination = target.destination {
            draw.wrappedValue.sphere(center: destination + Vector3(0, 0.2, 0), radius: 0.3, color: agent.lastError == nil ? .yellow : .red)
        }
        draw.wrappedValue.sphere(center: transform.position + Vector3(0, 0.06, 0), radius: 0.4, color: .mint)
        if let error = agent.lastError {
            state.setStatus(error == .targetOutsideMesh || error == .unreachable ? "Здесь нет прохода. Выбери другую точку." : "Ошибка маршрута: \(error)")
        } else {
            switch agent.follower.state {
            case .following: state.setStatus("Идём к цели · поворотов: \(max(0, (agent.follower.path?.points.count ?? 0) - 2))")
            case .arrived: state.setStatus("Пришли! Выбери следующую цель.")
            case .blocked: state.setStatus("Проход занят — ищем путь снова…")
            default: break
            }
        }
    }
}
