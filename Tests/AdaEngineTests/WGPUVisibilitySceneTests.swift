#if canImport(WebGPU) && (os(Windows) || os(macOS))
    @_spi(Internal) @testable import AdaApp
    import AdaCorePipelines
    import AdaECS
    @_spi(Internal) @testable import AdaRender
    import AdaScene
    import AdaTransform
    import AdaUtils
    import Foundation
    import Math
    import Testing

    extension Render3DGPUTests {
        /// Enable explicitly; shares serialization with the other 3D GPU suites.
        @MainActor
        @Suite("WebGPU Hi-Z 3D scene", .serialized)
        struct WGPUVisibilitySceneTests {
            @Test(.enabled(if: ProcessInfo.processInfo.environment["ADAENGINE_WEBGPU_SCENE_SMOKE"] == "1"))
            func matchesCPUFramesAcrossCameraMotionOccluderRemovalEffectsAndResize() async throws {
                unsafe RenderEngine.configurations.preferredBackend = .webgpu
                try RenderEngine.setupRenderEngine()
                let engine = try #require(unsafe RenderEngine.shared)
                try #require(engine.type == .webgpu)
                let device = engine.renderDevice
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

                var target = RenderTexture(size: [128, 96], scaleFactor: 1, format: .bgra8)
                var environment = Environment3D(antiAliasing: .fxaa)
                environment.skybox.isEnabled = false
                environment.screenSpaceReflection.isEnabled = false
                environment.shadows.isEnabled = false
                let eye = app.main.spawn("Camera", bundle: Camera3D(
                    camera: Camera(renderTarget: target), transform: Transform(position: [0, 0, -6]), environment: environment
                ))
                let wallMaterial = PBRMaterial()
                wallMaterial.baseColorFactor = [0.15, 0.6, 0.3, 1]
                let wall = app.main.spawn("Occluder") {
                    Mesh3DComponent(mesh: Mesh.generateCube(size: [5, 5, 0.5], renderDevice: device), materials: [wallMaterial])
                    Transform(position: [0, 0, 2])
                }
                let cube = Mesh.generateCube(size: [0.5, 0.5, 0.5], renderDevice: device)
                let material = PBRMaterial()
                material.baseColorFactor = [0.9, 0.2, 0.05, 1]
                var cubes: [Entity] = []
                for index in 0..<25 {
                    let entity = app.main.spawn("Hidden cube \(index)") {
                        Mesh3DComponent(mesh: cube, materials: [material])
                        Transform(position: [Float(index % 5 - 2) * 0.7, Float(index / 5 - 2) * 0.7, 7])
                    }
                    cubes.append(entity)
                }
                let sun = app.main.spawn("Sun") {
                    DirectionalLightComponent(intensity: 4, castShadows: false)
                    Transform(rotation: Quat.euler([-0.4, 0.5, 0]))
                }
                let render = try #require(app.getSubworldBuilder(by: .renderWorld)?.main)
                func frame(hiZ: Bool) async throws -> Image {
                    var settings = try #require(eye.components[Environment3D.self])
                    settings.gpuOcclusionEnabled = hiZ
                    eye.components[Environment3D.self] = settings
                    for _ in 0..<3 { try await app.update() }
                    if hiZ {
                        let output = try #require(render.getResource(GPUVisibility3DState.self)?.output(for: eye.id))
                        #expect(output.drawCount > 0)
                    }
                    return try #require(try await device.readImage(from: target))
                }
                func compare(_ scenario: String) async throws {
                    let reference = try await frame(hiZ: false)
                    let actual = try await frame(hiZ: true)
                    #expect(actual.data == reference.data, "Hi-Z changed pixels in \(scenario)")
                    if let directory = ProcessInfo.processInfo.environment["ADAENGINE_WEBGPU_SCENE_OUTPUT"] {
                        let folder = URL(fileURLWithPath: directory)
                        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        try reference.writePNG(to: folder.appendingPathComponent("\(scenario)-cpu.png"))
                        try actual.writePNG(to: folder.appendingPathComponent("\(scenario)-hiz.png"))
                    }
                }
                try await compare("occluded")
                let arguments = try #require(render.getResource(GPUVisibility3DState.self)?.output(for: eye.id)).arguments
                let packed = try await arguments.readData()
                let remaining = packed.withUnsafeBytes { bytes in
                    stride(from: 4, to: bytes.count, by: 20).reduce(0) { total, offset in
                        total + Int(unsafe bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
                    }
                }
                #expect(remaining > 0 && remaining < 26, "The depth prepass must actually reject hidden instances")
                eye.components[Transform.self] = Transform(position: [4, 0, -6])
                try await compare("camera-moved")
                let blocked = try await frame(hiZ: false)
                app.main.removeEntity(wall.id)
                try await compare("occluder-removed")
                let exposed = try await frame(hiZ: false)
                #expect(exposed.data != blocked.data, "Removing the wall must expose the cubes")
                let sources = try #require(render.getResource(ExtractedMesh3DSources.self))
                #expect(!sources.meshes.contains { $0.entity == wall.id })
                var effects = try #require(eye.components[Environment3D.self])
                effects.ambientOcclusion.isEnabled = true
                effects.screenSpaceReflection.isEnabled = true
                eye.components[Environment3D.self] = effects
                try await compare("screen-effects")
                target = RenderTexture(size: [127, 95], scaleFactor: 1, format: .bgra8)
                var resized = try #require(eye.components[Camera.self])
                resized.renderTarget = .texture(AssetHandle(target))
                eye.components[Camera.self] = resized
                try await compare("resized")
                let restored = try await frame(hiZ: false)
                let repeated = try await frame(hiZ: false)
                #expect(restored.data == repeated.data)

                // Compare the optimized shadow batches with genuinely separate GPU geometry.
                // Separate material objects intentionally share equivalent shadow bindings.
                var shadows = try #require(eye.components[Environment3D.self])
                shadows.shadows.isEnabled = true
                shadows.shadows.cascadeCount = 3
                shadows.localShadows.isEnabled = true
                eye.components[Environment3D.self] = shadows
                sun.components[DirectionalLightComponent.self]?.castShadows = true
                sun.components[Transform.self] = Transform(rotation: Quat.euler([0.8, 0.5, 0]))
                app.main.spawn("Shadow receiver") {
                    Mesh3DComponent(mesh: Mesh.generateCube(size: [10, 0.2, 10], renderDevice: device), materials: [wallMaterial])
                    Transform(position: [0, -2, 5])
                }
                app.main.spawn("Local shadow light") {
                    PointLightComponent(intensity: 30, castShadows: true, range: 20)
                    Transform(position: [3, 4, 2])
                }
                let descriptors = cube.models.flatMap { $0.parts.map(\.meshDescriptor) }
                for (index, entity) in cubes.enumerated() {
                    let color = PBRMaterial()
                    color.baseColorFactor = [0.2 + Float(index) * 0.02, 0.3, 0.1, 1]
                    entity.components[Mesh3DComponent.self] = Mesh3DComponent(
                        mesh: Mesh.generate(from: descriptors, renderDevice: device), materials: [color]
                    )
                }
                let separate = try await frame(hiZ: false)
                let statistics = try #require(render.getResource(Render3DVisibilityStatistics.self))
                let separateDraws = statistics.snapshots.filter { $0.key.contains(":shadow") }.values.reduce(0) { $0 + $1.drawCalls }
                for entity in cubes { entity.components[Mesh3DComponent.self]?.mesh = cube }
                let batched = try await frame(hiZ: false)
                let batchedDraws = statistics.snapshots.filter { $0.key.contains(":shadow") }.values.reduce(0) { $0 + $1.drawCalls }
                #expect(batchedDraws < separateDraws)
                #expect(batched.data == separate.data, "Instancing changed directional/local shadow pixels")
                var unshadowedSettings = shadows
                unshadowedSettings.shadows.isEnabled = false
                unshadowedSettings.localShadows.isEnabled = false
                eye.components[Environment3D.self] = unshadowedSettings
                let unshadowed = try await frame(hiZ: false)
                #expect(unshadowed.data != batched.data, "The comparison scene must contain visible shadows")
                eye.components[Environment3D.self] = shadows
                try await compare("batched-shadows")
                if let directory = ProcessInfo.processInfo.environment["ADAENGINE_WEBGPU_SCENE_OUTPUT"] {
                    try separate.writePNG(to: URL(fileURLWithPath: directory).appendingPathComponent("shadow-unbatched.png"))
                    try batched.writePNG(to: URL(fileURLWithPath: directory).appendingPathComponent("shadow-batched.png"))
                    try unshadowed.writePNG(to: URL(fileURLWithPath: directory).appendingPathComponent("shadow-disabled.png"))
                }
            }
        }
    }
#endif
