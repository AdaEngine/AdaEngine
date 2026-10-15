#if os(macOS)
@_spi(Internal) import AdaApp
@testable import AdaCorePipelines
import AdaEngine
@_spi(Internal) import AdaRender
import Foundation
import Metal
import Testing

/// Debug views and golden frames that need no GPU.
@Suite("3D debug view settings")
struct Render3DDebugViewSettingsTests {
    @Test func environmentDefaultsToNormalRendering() {
        #expect(Environment3D().debugView == DebugView3D.none)
    }

    @Test func legacyEnvironmentPayloadDecodesWithoutDebugView() throws {
        let legacy = try JSONEncoder().encode(Environment3D())
        var object = try #require(JSONSerialization.jsonObject(with: legacy) as? [String: Any])
        object.removeValue(forKey: "debugView")
        let stripped = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(Environment3D.self, from: stripped)
        #expect(decoded.debugView == DebugView3D.none)
    }

    @Test(arguments: DebugView3D.allCases)
    func debugViewRoundTrips(view: DebugView3D) throws {
        var environment = Environment3D()
        environment.debugView = view
        let decoded = try JSONDecoder().decode(Environment3D.self, from: JSONEncoder().encode(environment))
        #expect(decoded.debugView == view)
    }

    @Test func onlyFullscreenViewsReplaceTheFinalImage() {
        let replacing = DebugView3D.allCases.filter(\.replacesFinalImage)
        #expect(!replacing.contains(.none))
        #expect(!replacing.contains(.wireframe))
        #expect(replacing.count == DebugView3D.allCases.count - 2)
        // Each fullscreen view selects a distinct shader branch.
        #expect(Set(replacing.map(\.shaderMode)).count == replacing.count)
    }
}

/// Golden-frame harness logic that needs no GPU.
@Suite("Golden frame comparison")
struct GoldenFrameComparisonTests {
    private func solid(_ red: Float, width: Int = 8, height: Int = 8) -> Image {
        Image(width: width, height: height, color: Color(red: red, green: 0.5, blue: 0.5))
    }

    @Test func identicalImagesMatch() {
        let result = GoldenFrame.compare(solid(0.2), solid(0.2), tolerance: .metal)
        #expect(result.differingPixels == 0)
        #expect(result.passes(.metal))
    }

    @Test func differencesWithinChannelToleranceAreIgnored() {
        // 1/255 apart is below the two-step channel tolerance.
        let result = GoldenFrame.compare(solid(0.2), solid(0.2 + 1.0 / 255), tolerance: .metal)
        #expect(result.differingPixels == 0)
    }

    @Test func differencesBeyondToleranceFail() {
        var changed = solid(0.2)
        changed.setPixel(in: [3, 3], color: Color(red: 1, green: 0, blue: 0))
        let result = GoldenFrame.compare(changed, solid(0.2), tolerance: .metal)
        #expect(result.differingPixels == 1)
        #expect(result.largestStep > 2)
        #expect(!result.passes(.metal))
        // A looser fraction accepts the single pixel.
        #expect(result.passes(GoldenFrame.Tolerance(channelSteps: 2, differingFraction: 0.05)))
    }

    @Test func sizeMismatchAlwaysFails() {
        let result = GoldenFrame.compare(solid(0.2, width: 8), solid(0.2, width: 4), tolerance: GoldenFrame.Tolerance(channelSteps: 255, differingFraction: 1))
        #expect(result.sizeMismatch)
        #expect(!result.passes(GoldenFrame.Tolerance(channelSteps: 255, differingFraction: 1)))
    }
}

/// Renders a lit PBR scene through the real Metal pipeline for each debug view and checks the frames
/// against golden references.
///
/// Run alone: `ADAENGINE_GOLDEN_METAL=1 swift test --filter Render3DDebugViewMetalTests`.
/// Record references with `ADAENGINE_GOLDEN_RECORD=1`; set `ADAENGINE_GOLDEN_OUTPUT` to keep actual frames.
/// Other integration suites initialize the process-wide engine as headless.
@Suite("3D debug views on Metal", .serialized)
@MainActor
struct Render3DDebugViewMetalTests {
    private static let width = 640
    private static let height = 480
    /// Roughness and metallic of the four spheres from left to right.
    private static let roughness: [Float] = [0.1, 0.35, 0.65, 0.9]
    private static let metallic: [Float] = [0, 0.33, 0.66, 1]

    private struct Scene {
        let app: AppWorlds
        let device: RenderDevice
        let target: RenderTexture
        let queue: MTLCommandQueue
        let camera: Entity

        func render(_ view: DebugView3D, frames: Int = 4) async throws -> Image {
            var environment = try #require(camera.components[Environment3D.self])
            environment.debugView = view
            camera.components[Environment3D.self] = environment
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

        let target = RenderTexture(size: SizeInt(width: width, height: height), scaleFactor: 1, format: .bgra8)
        var environment = Environment3D(ambientOcclusion: .init(isEnabled: true))
        environment.skybox.isEnabled = false
        environment.screenSpaceReflection.isEnabled = false
        var camera = Camera(renderTarget: target)
        camera.backgroundColor = Color(red: 0.55, green: 0.7, blue: 0.9)
        // The camera looks along +Z at sphere centers, so the middle image row crosses all four spheres.
        let cameraEntity = app.main.spawn(
            "Camera",
            bundle: Camera3D(camera: camera, transform: Transform(position: [0, 0.5, -3.4]), environment: environment)
        )
        app.main.spawn("Sun") {
            DirectionalLightComponent(radiance: [1, 0.95, 0.85], intensity: 3, castShadows: true)
            Transform(rotation: Quat.euler([-0.9, 0.6, 0]))
        }
        let sphere = Mesh.generateSphere(radius: 0.5, renderDevice: device)
        for index in 0..<4 {
            let material = PBRMaterial()
            material.baseColorFactor = [0.8, 0.45, 0.3, 1]
            material.roughnessFactor = roughness[index]
            material.metallicFactor = metallic[index]
            app.main.spawn("Sphere \(index)") {
                Mesh3DComponent(mesh: sphere, materials: [material])
                Transform(position: [Float(index) * 1.1 - 1.65, 0.5, 0])
            }
        }
        let ground = PBRMaterial()
        ground.baseColorFactor = [0.35, 0.4, 0.35, 1]
        ground.roughnessFactor = 0.9
        ground.metallicFactor = 0
        app.main.spawn("Ground") {
            Mesh3DComponent(mesh: Mesh.generateCube(size: [10, 0.1, 10], renderDevice: device), materials: [ground])
            Transform(position: [0, -0.05, 0])
        }
        return Scene(app: app, device: device, target: target, queue: queue, camera: cameraEntity)
    }

    /// Gray levels (0...1) at the center of each covered run on one image row, left to right.
    private static func runCenters(in image: Image, row: Int, threshold: Float = 0.08) -> [Float] {
        var centers: [Float] = []
        var start: Int?
        for x in 0...image.width {
            let covered = x < image.width && image.getPixel(x: x, y: row).red > threshold
            if covered, start == nil {
                start = x
            } else if !covered, let begin = start {
                if x - begin > 12 {
                    centers.append(image.getPixel(x: (begin + x) / 2, y: row).red)
                }
                start = nil
            }
        }
        return centers
    }

    nonisolated private static let enabled = ProcessInfo.processInfo.environment["ADAENGINE_GOLDEN_METAL"] == "1"

    @Test(.enabled(if: Render3DDebugViewMetalTests.enabled))
    func roughnessAndMetallicViewsReportMaterialValues() async throws {
        let scene = try await Self.makeScene()
        let roughness = try await scene.render(.roughness)
        let metallic = try await scene.render(.metallic)
        let middle = Self.height / 2
        let roughnessLevels = Self.runCenters(in: roughness, row: middle)
        let metallicLevels = Self.runCenters(in: metallic, row: middle)
        // Metallic zero renders at the dark floor of the view, so runs are found by roughness only.
        #expect(roughnessLevels.count >= 4)
        for (level, expected) in zip(roughnessLevels, Self.roughness) {
            #expect(abs(level - expected) < 0.06, "roughness level \(level) should be near \(expected)")
        }
        #expect(metallicLevels.count >= 3)
        #expect(metallicLevels.last.map { $0 > 0.9 } == true)
    }

    @Test(.enabled(if: Render3DDebugViewMetalTests.enabled))
    func everyViewMatchesItsGoldenFrame() async throws {
        let scene = try await Self.makeScene()
        let beauty = try await scene.render(.none)
        for view in DebugView3D.allCases {
            let image = view == .none ? beauty : try await scene.render(view)
            if view != .none {
                #expect(image.data != beauty.data, "\(view) must change the image")
            }
            let name = "pbr-spheres-\(view.rawValue)"
            switch try GoldenFrame.check(image, name: name) {
            case .recorded, .matched:
                break
            case .missingReference(let actual):
                Issue.record("No golden frame for \(name); record with ADAENGINE_GOLDEN_RECORD=1. Actual: \(actual.path)")
            case .mismatched(let comparison, let actual, let difference):
                Issue.record("\(name) differs in \(comparison.differingPixels) pixels (largest step \(comparison.largestStep)). Actual: \(actual.path), difference: \(difference.path)")
            }
        }
    }

    @Test(.enabled(if: Render3DDebugViewMetalTests.enabled))
    func noneViewIsStableAcrossViewSwitches() async throws {
        let scene = try await Self.makeScene()
        let first = try await scene.render(.none)
        _ = try await scene.render(.normals)
        let second = try await scene.render(.none)
        let comparison = GoldenFrame.compare(first, second, tolerance: .metal)
        #expect(comparison.passes(.metal), "Leaving a debug view must restore normal rendering (\(comparison.differingPixels) pixels differ).")
    }
}
#endif
