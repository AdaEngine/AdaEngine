import AdaECS
@_spi(Internal) import AdaRender
import AdaTransform
import AdaUtils
import Foundation
import Math
import Testing

@testable import AdaScene

/// The camera side of pixel-perfect rendering, run with the real transform, camera and controller systems.
@MainActor
@Suite("Pixel perfect camera", .serialized)
struct PixelPerfectCameraTests {
    private let output = SizeInt(width: 200, height: 100)
    private let resolution = SizeInt(width: 64, height: 36)

    private func makeWorld() throws -> World {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            try RenderEngine.setupRenderEngine()
        }
        Transform.registerComponent()
        GlobalTransform.registerComponent()
        Camera.registerComponent()
        Camera2DController.registerComponent()
        let world = World()
        world.addSystem(CameraSystem.self, on: .preUpdate)
        world.addSystem(TransformSystem.self, on: .postUpdate)
        world.addSystem(ChildTransformSystem.self, on: .postUpdate)
        world.addSystem(Camera2DControllerSystem.self, on: .postUpdate)
        return world
    }

    private func spawnCamera(in world: World, pixelPerfect: PixelPerfectSettings?, controller: Camera2DController? = nil) -> Entity {
        var camera = Camera(renderTarget: RenderTexture(size: output, scaleFactor: 1, format: .bgra8))
        camera.pixelPerfect = pixelPerfect
        if let controller {
            return world.spawn { camera; Transform(); controller }
        }
        return world.spawn { camera; Transform() }
    }

    /// Where a world point lands in clip space with the camera's own projection.
    private func clip(_ camera: Entity, _ point: Vector2) throws -> Vector2 {
        let matrix = try #require(camera.components[Camera.self]).computedData.projectionMatrix
        let result = matrix * Vector4(point.x, point.y, 0, 1)
        return Vector2(result.x, result.y)
    }

    @Test("The projection covers the fixed resolution, not the window, and follows the setting when it changes")
    func projectionUsesResolution() async throws {
        let world = try makeWorld()
        let camera = spawnCamera(in: world, pixelPerfect: PixelPerfectSettings(resolution: resolution))
        await world.runScheduler(.preUpdate, deltaTime: 1.0 / 60)
        // 64x36 resolution: its right and top edges are 32 and 18 world units from the centre.
        let edge = try clip(camera, Vector2(32, 18))
        #expect(abs(edge.x - 1) < 0.0001 && abs(edge.y - 1) < 0.0001)

        camera.components[Camera.self]?.pixelPerfect = nil
        await world.runScheduler(.preUpdate, deltaTime: 1.0 / 60)
        let window = try clip(camera, Vector2(100, 50))
        #expect(abs(window.x - 1) < 0.0001 && abs(window.y - 1) < 0.0001)

        camera.components[Camera.self]?.pixelPerfect = PixelPerfectSettings(resolution: SizeInt(width: 128, height: 72))
        await world.runScheduler(.preUpdate, deltaTime: 1.0 / 60)
        let other = try clip(camera, Vector2(64, 36))
        #expect(abs(other.x - 1) < 0.0001 && abs(other.y - 1) < 0.0001)
    }

    @Test("An invalid setting leaves the camera on the window")
    func invalidSettingIgnored() async throws {
        let world = try makeWorld()
        let camera = spawnCamera(in: world, pixelPerfect: PixelPerfectSettings(resolution: SizeInt(width: 0, height: 36)))
        await world.runScheduler(.preUpdate, deltaTime: 1.0 / 60)
        let edge = try clip(camera, Vector2(100, 50))
        #expect(abs(edge.x - 1) < 0.0001 && abs(edge.y - 1) < 0.0001)
    }

    @Test("Zoom keeps its meaning: one world unit is one art pixel at zoom 1 and two at zoom 2")
    func zoomInArtPixels() async throws {
        let world = try makeWorld()
        var controller = Camera2DController(zoom: 2)
        controller.snapsToPixels = true
        let camera = spawnCamera(in: world, pixelPerfect: PixelPerfectSettings(resolution: resolution), controller: controller)
        await world.runScheduler(.preUpdate, deltaTime: 1.0 / 60)
        await world.runScheduler(.postUpdate, deltaTime: 1.0 / 60)
        // At zoom 2 the 64x36 picture shows 32x18 world units, so 16 and 9 reach the edges.
        let edge = try clip(camera, Vector2(16, 9))
        #expect(abs(edge.x - 1) < 0.0001 && abs(edge.y - 1) < 0.0001)
    }

    @Test("Camera limits are measured against the picture's world size")
    func limitsUseTheResolution() async throws {
        let world = try makeWorld()
        var controller = Camera2DController()
        controller.limitsEnabled = true
        controller.limitMin = Vector2(0, 0)
        controller.limitMax = Vector2(640, 360)
        let camera = spawnCamera(in: world, pixelPerfect: PixelPerfectSettings(resolution: resolution), controller: controller)
        _ = world.spawn { Transform(position: [-1000, -1000, 0]); CameraTarget2D() }
        await world.runScheduler(.preUpdate, deltaTime: 1.0 / 60)
        await world.runScheduler(.postUpdate, deltaTime: 1.0 / 60)
        // The 64x36 view pins the camera 32 and 18 units inside the corner. A window-sized view (200x100) would give 100 and 50.
        #expect(camera.components[Camera2DController.self]?.position == Vector2(32, 18))
    }

    @Test("Window points map through the picture, so the letterbox border is outside it")
    func viewportMapping() async throws {
        let world = try makeWorld()
        let camera = spawnCamera(in: world, pixelPerfect: PixelPerfectSettings(resolution: resolution))
        await world.runScheduler(.preUpdate, deltaTime: 1.0 / 60)
        let value = try #require(camera.components[Camera.self])
        // 200x100 window, 64x36 picture: scale 2, picture 128x72 at (36, 14).
        let presentation = try #require(value.pixelPerfectPresentation)
        #expect(presentation == Rect(x: 36, y: 14, width: 128, height: 72))

        let center = try #require(value.viewportToWorld2D(cameraGlobalTransform: .identity, viewportPosition: Vector2(100, 50)))
        #expect(abs(center.x) < 0.001 && abs(center.y) < 0.001)
        let left = try #require(value.viewportToWorld2D(cameraGlobalTransform: .identity, viewportPosition: Vector2(36, 50)))
        let right = try #require(value.viewportToWorld2D(cameraGlobalTransform: .identity, viewportPosition: Vector2(164, 50)))
        #expect(abs(left.x + 32) < 0.001 && abs(right.x - 32) < 0.001)
        let border = try #require(value.viewportToWorld2D(cameraGlobalTransform: .identity, viewportPosition: Vector2(0, 50)))
        #expect(border.x < -32, "the border lies outside the picture's world area")
    }
}
