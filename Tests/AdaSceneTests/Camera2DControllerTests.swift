import AdaECS
@_spi(Internal) import AdaRender
import AdaTransform
import AdaUtils
import Foundation
import Math
import Testing

@testable import AdaScene

/// Runs the controller with the real transform and camera systems, so the view the frame is drawn with is what is checked.
@MainActor
@Suite("Camera2D controller", .serialized)
struct Camera2DControllerTests {
    private let viewport = SizeInt(width: 200, height: 100)

    private func makeWorld() throws -> World {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            try RenderEngine.setupRenderEngine()
        }
        Transform.registerComponent()
        GlobalTransform.registerComponent()
        Camera.registerComponent()
        Camera2DController.registerComponent()
        CameraTarget2D.registerComponent()
        let world = World()
        world.addSystem(CameraSystem.self, on: .preUpdate)
        world.addSystem(TransformSystem.self, on: .postUpdate)
        world.addSystem(ChildTransformSystem.self, on: .postUpdate)
        world.addSystem(Camera2DControllerSystem.self, on: .postUpdate)
        return world
    }

    private func spawnCamera(
        in world: World,
        at position: Vector3 = .zero,
        configure: (inout Camera2DController) -> Void = { _ in }
    ) -> Entity {
        var controller = Camera2DController()
        configure(&controller)
        let camera = Camera(renderTarget: RenderTexture(size: viewport, scaleFactor: 1, format: .bgra8))
        return world.spawn { camera; Transform(position: position); controller }
    }

    private func spawnTarget(in world: World, at position: Vector3, group: String = "", weight: Float = 1) -> Entity {
        world.spawn { Transform(position: position); CameraTarget2D(group: group, weight: weight) }
    }

    /// One frame: camera update, then the game moves things, then transforms propagate and the controller runs.
    private func frame(_ world: World, _ delta: AdaUtils.TimeInterval = 1.0 / 60, move: () -> Void = {}) async {
        await world.runScheduler(.preUpdate, deltaTime: delta)
        move()
        await world.runScheduler(.postUpdate, deltaTime: delta)
    }

    /// Where the camera looks, as the renderer sees it: the position encoded in the view matrix.
    private func viewedPosition(_ camera: Entity) throws -> Vector2 {
        let view = try #require(camera.components[Camera.self]).viewMatrix.inverse.origin
        return Vector2(view.x, view.y)
    }

    @Test("The view is on the target in the same frame the target moved, not a frame later")
    func followsWithoutLag() async throws {
        let world = try makeWorld()
        let target = spawnTarget(in: world, at: [10, 5, 0])
        let camera = spawnCamera(in: world)
        await frame(world)
        #expect(try viewedPosition(camera) == Vector2(10, 5))

        await frame(world) { target.components[Transform.self]?.position = [120, 40, 0] }
        #expect(try viewedPosition(camera) == Vector2(120, 40))
        let uniform = try #require(camera.components[GlobalViewUniform.self])
        #expect(uniform.viewMatrix.inverse.origin.x == 120 && uniform.viewMatrix.inverse.origin.y == 40)
        #expect(camera.components[Transform.self]?.position == Vector3(120, 40, 0))

        // The next frame's own camera update reproduces the same view, so nothing drifts or jumps back.
        await world.runScheduler(.preUpdate, deltaTime: 1.0 / 60)
        #expect(try viewedPosition(camera) == Vector2(120, 40))
    }

    @Test("Followed entities with a parent are tracked at their world position")
    func followsChildren() async throws {
        let world = try makeWorld()
        let parent = world.spawn { Transform(position: [100, 0, 0]) }
        let child = world.spawn { Transform(position: [20, 7, 0]); CameraTarget2D() }
        parent.addChild(child)
        let camera = spawnCamera(in: world)
        await frame(world)
        await frame(world)
        #expect(try viewedPosition(camera) == Vector2(120, 7))
    }

    @Test("Smoothing reaches the same place after the same time at 60 and at 10 frames per second")
    func smoothingIsFrameRateIndependent() async throws {
        var results: [Vector2] = []
        for (frames, step) in [(60, AdaUtils.TimeInterval(1.0 / 60)), (10, AdaUtils.TimeInterval(0.1))] {
            let world = try makeWorld()
            let target = spawnTarget(in: world, at: .zero)
            let camera = spawnCamera(in: world) { $0.smoothingTime = 0.3 }
            await frame(world, step)
            for _ in 0..<frames { await frame(world, step) { target.components[Transform.self]?.position = [100, 0, 0] } }
            results.append(try viewedPosition(camera))
        }
        let expected = 100 * (1 - Float(exp(-1.0 / 0.3)))
        #expect(abs(results[0].x - expected) < 1.5)
        #expect(abs(results[0].x - results[1].x) < 1.5)
    }

    @Test("The dead zone lets the target wander and then drags the camera along its edge")
    func deadZone() async throws {
        let world = try makeWorld()
        let target = spawnTarget(in: world, at: .zero)
        let camera = spawnCamera(in: world) { $0.deadZone = Vector2(40, 20) }
        await frame(world)
        await frame(world) { target.components[Transform.self]?.position = [15, -8, 0] }
        #expect(try viewedPosition(camera) == .zero)
        await frame(world) { target.components[Transform.self]?.position = [50, 30, 0] }
        #expect(try viewedPosition(camera) == Vector2(30, 20))
    }

    @Test("Limits keep the visible area inside, and the camera returns as soon as the target does")
    func limits() async throws {
        let world = try makeWorld()
        let target = spawnTarget(in: world, at: [10, 10, 0])
        let camera = spawnCamera(in: world) {
            $0.limitsEnabled = true
            $0.limitMin = Vector2(0, 0)
            $0.limitMax = Vector2(1000, 500)
        }
        await frame(world)
        // 200x100 viewport: the view is 100 wide and 50 high on each side of the camera.
        #expect(try viewedPosition(camera) == Vector2(100, 50))
        await frame(world) { target.components[Transform.self]?.position = [2000, 900, 0] }
        #expect(try viewedPosition(camera) == Vector2(900, 450))
        await frame(world) { target.components[Transform.self]?.position = [890, 450, 0] }
        #expect(try viewedPosition(camera) == Vector2(890, 450))
    }

    @Test("Zoom sets the projection scale, is clamped, and smooths toward its target")
    func zoom() async throws {
        let world = try makeWorld()
        let camera = spawnCamera(in: world) {
            $0.zoom = 2
            $0.maxZoom = 4
        }
        await frame(world)
        func scale() throws -> Float {
            guard case .orthographic(let projection) = try #require(camera.components[Camera.self]).projection else { return 0 }
            return projection.scale
        }
        #expect(try scale() == 2)

        camera.components[Camera2DController.self]?.zoom = 100
        await frame(world)
        #expect(try scale() == 4)

        camera.components[Camera2DController.self]?.zoomSmoothingTime = 0.2
        camera.components[Camera2DController.self]?.zoom = 1
        await frame(world, 0.2)
        let partway = try scale()
        #expect(partway < 4 && partway > 1)
        for _ in 0..<120 { await frame(world, 0.1) }
        #expect(abs(try scale() - 1) < 0.001)
        #expect(abs((camera.components[Camera2DController.self]?.visibleZoom ?? 0) - 1) < 0.001)

        // The visible area follows the projection: at zoom 2 a 200x100 viewport shows 100x50 world units.
        camera.components[Camera2DController.self]?.zoomSmoothingTime = 0
        camera.components[Camera2DController.self]?.zoom = 2
        await frame(world)
        let clip = try #require(camera.components[Camera.self]).computedData.projectionMatrix
        let edge = clip * Vector4(50, 25, 0, 1)
        #expect(abs(edge.x - 1) < 0.0001 && abs(edge.y - 1) < 0.0001)
    }

    @Test("Shake displaces the camera around the followed point and settles exactly back on it")
    func shake() async throws {
        let world = try makeWorld()
        _ = spawnTarget(in: world, at: [50, 20, 0])
        let camera = spawnCamera(in: world) {
            $0.shakeMaxOffset = Vector2(12, 12)
            $0.shakeMaxRoll = 6
            $0.traumaDecay = 1
        }
        await frame(world)
        #expect(try viewedPosition(camera) == Vector2(50, 20))

        camera.components[Camera2DController.self]?.addTrauma(1)
        var farthest: Float = 0
        var rolled = false
        for _ in 0..<30 {
            await frame(world, 1.0 / 60)
            let position = try viewedPosition(camera)
            farthest = max(farthest, abs(position.x - 50), abs(position.y - 20))
            #expect(abs(position.x - 50) <= 12.001 && abs(position.y - 20) <= 12.001)
            if camera.components[Transform.self]?.rotation != .identity { rolled = true }
        }
        #expect(farthest > 1)
        #expect(rolled)
        // The follow position underneath is untouched by the shake.
        #expect(camera.components[Camera2DController.self]?.position == Vector2(50, 20))

        for _ in 0..<80 { await frame(world, 0.1) }
        #expect(camera.components[Camera2DController.self]?.trauma == 0)
        #expect(try viewedPosition(camera) == Vector2(50, 20))
        #expect(camera.components[Transform.self]?.rotation == .identity)
    }

    @Test("A camera without roll shake keeps whatever rotation it was given")
    func rotationUntouched() async throws {
        let world = try makeWorld()
        _ = spawnTarget(in: world, at: [5, 5, 0])
        let camera = spawnCamera(in: world)
        let tilt = Quat(axis: Vector3(0, 0, 1), angle: 0.4)
        camera.components[Transform.self]?.rotation = tilt
        camera.components[Camera2DController.self]?.addTrauma(1)
        await frame(world)
        await frame(world)
        #expect(camera.components[Transform.self]?.rotation == tilt)
    }

    @Test("Pixel snapping puts the camera on the pixel grid of the current zoom")
    func pixelSnapping() async throws {
        let world = try makeWorld()
        let target = spawnTarget(in: world, at: [10.3, 4.1, 0])
        let camera = spawnCamera(in: world) {
            $0.zoom = 2
            $0.snapsToPixels = true
        }
        await frame(world)
        #expect(try viewedPosition(camera) == Vector2(10.5, 4))
        await frame(world) { target.components[Transform.self]?.position = [10.74, 4.26, 0] }
        #expect(try viewedPosition(camera) == Vector2(10.5, 4.5))
    }

    @Test("Several targets share the camera by weight, and groups are independent")
    func groupsAndWeights() async throws {
        let world = try makeWorld()
        _ = spawnTarget(in: world, at: [0, 0, 0], group: "players", weight: 1)
        _ = spawnTarget(in: world, at: [100, 0, 0], group: "players", weight: 3)
        _ = spawnTarget(in: world, at: [-500, 0, 0], group: "other")
        _ = spawnTarget(in: world, at: [900, 0, 0], group: "players", weight: 0)
        let players = spawnCamera(in: world) { $0.targetGroup = "players" }
        let others = spawnCamera(in: world) { $0.targetGroup = "other" }
        let nobody = spawnCamera(in: world, at: [7, 8, 0]) { $0.targetGroup = "missing" }
        await frame(world)
        let playersPosition = try viewedPosition(players)
        #expect(playersPosition == Vector2(75, 0), "players camera looks at \(playersPosition)")
        #expect(try viewedPosition(others) == Vector2(-500, 0))
        // Without any target the camera stays where it was placed instead of snapping to the origin.
        #expect(try viewedPosition(nobody) == Vector2(7, 8))
    }

    @Test("Every camera gets its view uniform on the first pass, however many cameras there are")
    func allCamerasPublishViews() async throws {
        let world = try makeWorld()
        // Without controllers, so this covers CameraSystem itself: a first uniform changes the camera's archetype.
        var cameras: [Entity] = []
        for index in 0..<5 {
            let camera = Camera(renderTarget: RenderTexture(size: viewport, scaleFactor: 1, format: .bgra8))
            cameras.append(world.spawn { camera; Transform(position: [Float(index) * 10, 0, 0]) })
        }
        await world.runScheduler(.postUpdate, deltaTime: 1.0 / 60)
        await world.runScheduler(.preUpdate, deltaTime: 1.0 / 60)
        for (index, camera) in cameras.enumerated() {
            let uniform = try #require(camera.components[GlobalViewUniform.self], "camera \(index) has no view uniform")
            #expect(uniform.viewMatrix.inverse.origin.x == Float(index) * 10)
        }
    }

    @Test("The offset shifts the followed point")
    func offset() async throws {
        let world = try makeWorld()
        _ = spawnTarget(in: world, at: [10, 10, 0])
        let camera = spawnCamera(in: world) { $0.offset = Vector2(30, -5) }
        await frame(world)
        #expect(try viewedPosition(camera) == Vector2(40, 5))
    }

    @Test("snapCount jumps to the target through smoothing, and position moves a camera that has no target")
    func snappingAndManualControl() async throws {
        let world = try makeWorld()
        let target = spawnTarget(in: world, at: .zero)
        let camera = spawnCamera(in: world) { $0.smoothingTime = 5 }
        await frame(world)
        await frame(world) { target.components[Transform.self]?.position = [200, 0, 0] }
        #expect(try viewedPosition(camera).x < 20)
        camera.components[Camera2DController.self]?.snapCount += 1
        await frame(world)
        #expect(try viewedPosition(camera) == Vector2(200, 0))

        let free = spawnCamera(in: world) { $0.targetGroup = "none" }
        await frame(world)
        free.components[Camera2DController.self]?.position = Vector2(33, -12)
        await frame(world)
        #expect(try viewedPosition(free) == Vector2(33, -12))
        free.components[Camera2DController.self]?.snap(to: Vector2(-4, 9))
        await frame(world)
        #expect(try viewedPosition(free) == Vector2(-4, 9))
    }

    @Test("A disabled controller leaves the camera to its transform")
    func disabled() async throws {
        let world = try makeWorld()
        _ = spawnTarget(in: world, at: [300, 300, 0])
        let camera = spawnCamera(in: world, at: [1, 2, 0]) { $0.isEnabled = false }
        await frame(world)
        await frame(world)
        #expect(try viewedPosition(camera) == Vector2(1, 2))
    }

    @Test("Hostile numbers cannot move the camera to NaN")
    func hostileValues() async throws {
        let world = try makeWorld()
        let target = spawnTarget(in: world, at: [10, 10, 0])
        let camera = spawnCamera(in: world) {
            $0.zoom = .nan
            $0.minZoom = .infinity
            $0.maxZoom = -3
            $0.smoothingTime = .nan
            $0.traumaDecay = -4
            $0.deadZone = Vector2(.nan, -1)
        }
        camera.components[Camera2DController.self]?.addTrauma(.nan)
        await frame(world)
        await frame(world, .nan) { target.components[Transform.self]?.position = [20, 20, 0] }
        await frame(world, -1)
        let position = try viewedPosition(camera)
        #expect(position.x.isFinite && position.y.isFinite)
        guard case .orthographic(let projection) = try #require(camera.components[Camera.self]).projection else { return }
        #expect(projection.scale.isFinite && projection.scale > 0)
    }

    @Test("Settings survive Codable and sparse scenes keep the defaults")
    func coding() throws {
        var controller = Camera2DController(targetGroup: "hero", smoothingTime: 0.25, zoom: 3)
        controller.deadZone = Vector2(8, 4)
        controller.limitsEnabled = true
        controller.limitMax = Vector2(640, 480)
        controller.shakeMaxRoll = 2
        controller.snapsToPixels = true
        let copy = try JSONDecoder().decode(Camera2DController.self, from: JSONEncoder().encode(controller))
        #expect(copy.targetGroup == "hero" && copy.smoothingTime == 0.25 && copy.zoom == 3)
        #expect(copy.deadZone == Vector2(8, 4) && copy.limitsEnabled && copy.limitMax == Vector2(640, 480))
        #expect(copy.shakeMaxRoll == 2 && copy.snapsToPixels)

        let sparse = try JSONDecoder().decode(Camera2DController.self, from: Data("{}".utf8))
        #expect(sparse.isEnabled && sparse.zoom == 1 && sparse.maxZoom == 16 && sparse.traumaDecay == 1 && !sparse.limitsEnabled)
        let target = try JSONDecoder().decode(CameraTarget2D.self, from: JSONEncoder().encode(CameraTarget2D(group: "a", weight: 2)))
        #expect(target.group == "a" && target.weight == 2)
    }
}
