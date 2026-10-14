#if os(macOS)
@_spi(Internal) import AdaApp
import AdaEngine
@_spi(Internal) import AdaRender
import Foundation
import Metal
import Testing

/// Renders imported MagicaVoxel models through the real Metal 3D pipeline and writes PNGs for inspection.
///
/// Run alone: `ADAENGINE_VOXEL_METAL_SMOKE=1 swift test --filter VoxelRenderingSmokeTests`.
/// Other integration suites initialize the process-wide engine as headless.
@Suite("Voxel Metal scene", .serialized)
@MainActor
struct VoxelRenderingSmokeTests {
    private static let outputDirectory = ProcessInfo.processInfo.environment["ADAENGINE_VOXEL_SMOKE_OUTPUT"] ?? "/tmp"

    private static func fixtureURL(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AdaAssetsTests/Fixtures/vox/\(name).vox")
    }

    private struct Scene {
        let app: AppWorlds
        let device: RenderDevice
        let target: RenderTexture
        let queue: MTLCommandQueue

        func render(frames: Int = 1) async throws -> Image {
            for _ in 0..<frames {
                try await app.update()
            }
            let fence = try #require(queue.makeCommandBuffer())
            await withCheckedContinuation { continuation in
                fence.addCompletedHandler { _ in continuation.resume() }
                fence.commit()
            }
            return try #require(device.getImage(from: target))
        }
    }

    private static func makeScene() async throws -> Scene {
        unsafe RenderEngine.configurations.preferredBackend = .metal
        try RenderEngine.setupRenderEngine()
        let device = unsafe RenderEngine.shared.renderDevice
        let queue = try #require(MetalInterop.commandQueue(for: device))
        let app = AppWorlds(main: World())
        app.insertResource(OffscreenRenderWorld())
            .insertResource(PrimaryWindowId(windowId: RID()))
            .addPlugin(MainSchedulerPlugin())
            .addPlugin(TransformPlugin())
            .addPlugin(RenderWorldPlugin())
            .addPlugin(EventsPlugin())
            .addPlugin(CameraPlugin())
            .addPlugin(AssetsPlugin(filePath: #filePath))
            .addPlugin(VisibilityPlugin())
            .addPlugin(ScenePlugin())
            .addPlugin(Core3DPlugin())
        try await app.build()

        let target = RenderTexture(size: SizeInt(width: 640, height: 480), scaleFactor: 1, format: .bgra8)
        var environment = Environment3D(ambientOcclusion: .init(isEnabled: true), antiAliasing: .fxaa)
        environment.skybox.isEnabled = false
        environment.screenSpaceReflection.isEnabled = false
        var camera = Camera(renderTarget: target)
        camera.backgroundColor = Color(0.55, 0.7, 0.9, 1)
        app.main.spawn(
            "Camera",
            bundle: Camera3D(
                camera: camera,
                transform: Transform(rotation: Quat(axis: [1, 0, 0], angle: 0.45), position: [0, 1.7, -2.6]),
                environment: environment
            )
        )
        app.main.spawn("Sun") {
            DirectionalLightComponent(radiance: [1, 0.95, 0.85], intensity: 3, castShadows: true)
            Transform(rotation: Quat.euler([-0.9, 0.6, 0]))
        }
        return Scene(app: app, device: device, target: target, queue: queue)
    }

    private static func nonBackgroundPixels(in image: Image) -> Int {
        var count = 0
        for y in stride(from: 0, to: 480, by: 4) {
            for x in stride(from: 0, to: 640, by: 4) {
                let offset = (y * 640 + x) * 4
                // Background is (0.55, 0.7, 0.9) -> BGRA (230, 178, 140) before tone mapping; compare against the corner pixel.
                let corner = 0
                let differs = (0..<3).contains { abs(Int(image.data[offset + $0]) - Int(image.data[corner + $0])) > 24 }
                if differs {
                    count += 1
                }
            }
        }
        return count
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["ADAENGINE_VOXEL_METAL_SMOKE"] == "1"))
    func rendersImportedCastle() async throws {
        let scene = try await Self.makeScene()
        let model = try #require(await AssetsManager.load(ModelAsset3D.self, at: Self.fixtureURL("castle").path).asset)
        let root = model.instantiate(in: scene.app.main)
        root.components[Transform.self] = Transform(position: [0, 0.6, 0])

        let image = try await scene.render(frames: 4)
        try image.writePNG(to: URL(fileURLWithPath: "\(Self.outputDirectory)/adaengine-voxel-castle.png"))
        #expect(Self.nonBackgroundPixels(in: image) > 1500)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["ADAENGINE_VOXEL_METAL_SMOKE"] == "1"))
    func rendersImportedRobotWithMergedStaticParts() async throws {
        let scene = try await Self.makeScene()
        let file = try await VOXLoader().load(url: Self.fixtureURL("robot"))
        let model = ModelAsset3D(voxelFile: file, options: VoxelImportOptions(mergeStatic: true))
        let root = model.instantiate(in: scene.app.main)
        root.components[Transform.self] = Transform(position: [0, 0.8, 0])

        let image = try await scene.render(frames: 4)
        try image.writePNG(to: URL(fileURLWithPath: "\(Self.outputDirectory)/adaengine-voxel-robot.png"))
        #expect(Self.nonBackgroundPixels(in: image) > 600)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["ADAENGINE_VOXEL_METAL_SMOKE"] == "1"))
    func rendersRobotAnimationFrames() async throws {
        let scene = try await Self.makeScene()
        let file = try await VOXLoader().load(url: Self.fixtureURL("robot"))
        let model = ModelAsset3D(voxelFile: file, options: VoxelImportOptions(mergeStatic: true))
        let root = model.instantiate(in: scene.app.main)
        root.components[Transform.self] = Transform(position: [0, 0.1, 0])

        var frames: [Image] = []
        for (name, frame) in [("start", 0.0), ("end", 10.0)] {
            var playback = try #require(root.components[VoxelAnimationPlayback3DComponent.self])
            playback.isPlaying = false
            playback.time = frame / playback.framesPerSecond
            root.components[VoxelAnimationPlayback3DComponent.self] = playback
            let image = try await scene.render(frames: 3)
            try image.writePNG(to: URL(fileURLWithPath: "\(Self.outputDirectory)/adaengine-voxel-robot-\(name).png"))
            frames.append(image)
        }
        // The arm moved, so the two renders differ.
        #expect(frames[0].data != frames[1].data)
    }
}
#endif
