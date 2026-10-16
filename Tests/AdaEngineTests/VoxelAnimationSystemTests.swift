import AdaEngine
@_spi(Internal) @testable import AdaApp
@_spi(Internal) @testable import AdaRender
import Foundation
import Testing

@MainActor
@Suite("Voxel animation system")
struct VoxelAnimationSystemTests {
    private static func fixtureURL(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AdaAssetsTests/Fixtures/vox/\(name).vox")
    }

    private static func makeApp() async throws -> AppWorlds {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            try RenderEngine.setupRenderEngine()
        }
        let app = AppWorlds(main: World())
        app
            .addPlugin(MainSchedulerPlugin())
            .addPlugin(TransformPlugin())
            .addPlugin(RenderWorldPlugin())
            .addPlugin(Model3DPlugin())
        try await app.build()
        return app
    }

    private static func descendants(of entity: Entity) -> [Entity] {
        entity.children.flatMap { [$0] + descendants(of: $0) }
    }

    private static func step(_ app: AppWorlds, seconds: Double) async {
        await app.main.runScheduler(.postUpdate, deltaTime: Float(seconds))
    }

    private static func near(_ lhs: Quat, _ rhs: Quat) -> Bool {
        abs(lhs.dot(rhs)) > 0.9999
    }

    private func loadRobot() async throws -> ModelAsset3D {
        let file = try await VOXLoader().load(url: Self.fixtureURL("robot"))
        return ModelAsset3D(voxelFile: file)
    }

    @Test("robot arm rotates between its MagicaVoxel keyframes")
    func animatesArmTransform() async throws {
        let app = try await Self.makeApp()
        let model = try await loadRobot()
        let timeline = try #require(model.voxelTimeline)
        #expect(timeline.frameCount == 11)

        let root = model.instantiate(in: app.main)
        let arm = try #require(Self.descendants(of: root).first { $0.name == "arm" })
        let keys = try #require(model.nodes.first { $0.name == "arm" }?.voxelAnimation).transformKeys
        let start = try #require(arm.components[Transform.self])
        #expect(Self.near(start.rotation, keys[0].transform.rotation))

        // 1/3 s at 30 fps is frame 10, the last key.
        await Self.step(app, seconds: 1.0 / 3)
        let end = try #require(arm.components[Transform.self])
        #expect(Self.near(end.rotation, keys[1].transform.rotation))
        #expect(!Self.near(end.rotation, keys[0].transform.rotation))
        #expect(end.position == keys[1].transform.position)

        // Halfway through the timeline the arm is between both poses.
        let halfway = try #require(root.components[VoxelAnimationPlayback3DComponent.self])
        #expect(halfway.isPlaying)
    }

    @Test("rotation is interpolated between keyframes")
    func interpolatesRotationMidway() async throws {
        let app = try await Self.makeApp()
        let model = try await loadRobot()
        let root = model.instantiate(in: app.main)
        let arm = try #require(Self.descendants(of: root).first { $0.name == "arm" })
        let keys = try #require(model.nodes.first { $0.name == "arm" }?.voxelAnimation).transformKeys

        await Self.step(app, seconds: 5.0 / 30)
        let middle = try #require(arm.components[Transform.self]).rotation
        let expected = VoxelNodeAnimation.slerp(keys[0].transform.rotation, keys[1].transform.rotation, 0.5)
        #expect(Self.near(middle, expected))
    }

    @Test("static parts keep their transform while the arm moves")
    func leavesStaticPartsAlone() async throws {
        let app = try await Self.makeApp()
        let model = try await loadRobot()
        let root = model.instantiate(in: app.main)
        let body = try #require(Self.descendants(of: root).first { $0.name == "body" })
        let before = try #require(body.components[Transform.self])

        await Self.step(app, seconds: 0.2)
        #expect(body.components[Transform.self] == before)
        #expect(body.components[VoxelTransformAnimation3DComponent.self] == nil)
    }

    @Test("clock loops and pause freezes the pose")
    func loopsAndPauses() async throws {
        let app = try await Self.makeApp()
        let model = try await loadRobot()
        let root = model.instantiate(in: app.main)

        // Timeline is 11 frames; 0.4 s is frame 12, wrapped to frame 1.
        await Self.step(app, seconds: 0.4)
        let looped = try #require(root.components[VoxelAnimationPlayback3DComponent.self])
        #expect(abs(looped.currentFrame - 1) < 0.01)

        var paused = looped
        paused.isPlaying = false
        root.components[VoxelAnimationPlayback3DComponent.self] = paused
        await Self.step(app, seconds: 0.2)
        #expect(root.components[VoxelAnimationPlayback3DComponent.self]?.time == looped.time)
    }

    @Test("Model3DSource autoplay controls voxel playback")
    func sourceAutoplayControlsVoxelPlayback() async throws {
        let app = try await Self.makeApp()
        let model = try await loadRobot()

        let idleOwner = app.main.spawn("Idle")
        let idle = try Model3DSource(autoplay: false).instantiate(model, in: app.main, under: idleOwner)
        let playingOwner = app.main.spawn("Playing")
        let playing = try Model3DSource(autoplay: true, repeats: false).instantiate(model, in: app.main, under: playingOwner)

        #expect(idle.components[VoxelAnimationPlayback3DComponent.self]?.isPlaying == false)
        #expect(playing.components[VoxelAnimationPlayback3DComponent.self]?.isPlaying == true)
        #expect(playing.components[VoxelAnimationPlayback3DComponent.self]?.repeats == false)
    }

    @Test("frame-by-frame shapes swap meshes and pivot offsets")
    func swapsMeshesFrameByFrame() async throws {
        let app = try await Self.makeApp()
        let single = VOXModel(sizeX: 1, sizeY: 1, sizeZ: 1, voxels: [VOXVoxel(x: 0, y: 0, z: 0, colorIndex: 1)])
        let split = VOXModel(
            sizeX: 3,
            sizeY: 1,
            sizeZ: 1,
            voxels: [VOXVoxel(x: 0, y: 0, z: 0, colorIndex: 1), VOXVoxel(x: 2, y: 0, z: 0, colorIndex: 1)]
        )
        let file = VOXFile(
            models: [single, split],
            nodes: [
                0: .transform(VOXTransformNode(id: 0, childID: 1)),
                1: .shape(VOXShapeNode(id: 1, models: [.init(modelIndex: 0, frameIndex: 0), .init(modelIndex: 1, frameIndex: 5)]))
            ]
        )
        let model = ModelAsset3D(voxelFile: file)
        let root = model.instantiate(in: app.main)
        let shape = try #require(Self.descendants(of: root).first { $0.components[Mesh3DComponent.self] != nil })

        func indexCount() -> Int? {
            shape.components[Mesh3DComponent.self]?.mesh.models.first?.parts.first?.indexCount
        }

        await Self.step(app, seconds: 0)
        #expect(indexCount() == 36)
        let firstOffset = try #require(shape.components[Transform.self]).position

        // The timeline has 6 frames (0...5); frame 5.2 shows the second model: two separate cubes.
        await Self.step(app, seconds: 5.2 / 30)
        #expect(indexCount() == 72)
        let secondOffset = try #require(shape.components[Transform.self]).position
        #expect(secondOffset != firstOffset)
        // The pivot of the 3x1x1 model is (1, 0, 0), scaled by the default voxel size.
        #expect(abs(secondOffset.x + 0.1) < 0.0001)
    }
}
