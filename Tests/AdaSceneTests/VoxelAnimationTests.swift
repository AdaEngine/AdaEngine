import AdaAssets
import AdaTransform
import Math
import Testing
@_spi(Internal) import AdaRender
@testable import AdaScene

@Suite
struct VoxelAnimationTests {
    private func near(_ lhs: Float, _ rhs: Float, tolerance: Float = 0.0001) -> Bool {
        abs(lhs - rhs) < tolerance
    }

    private func key(_ frame: Int, position: Vector3, rotation: Quat = .identity) -> VoxelNodeAnimation.TransformKey {
        .init(frame: frame, transform: Transform(rotation: rotation, scale: .one, position: position))
    }

    // MARK: - Evaluation

    @Test
    func interpolatesPositionBetweenKeysAndHoldsAtTheEnds() throws {
        let animation = VoxelNodeAnimation(transformKeys: [key(10, position: [10, 0, 0]), key(0, position: [0, 0, 0])])

        #expect(animation.lastFrame == 10)
        #expect(try #require(animation.transform(at: -3)).position == [0, 0, 0])
        #expect(near(try #require(animation.transform(at: 5)).position.x, 5))
        #expect(near(try #require(animation.transform(at: 2.5)).position.x, 2.5))
        #expect(try #require(animation.transform(at: 40)).position == [10, 0, 0])
    }

    @Test
    func interpolatesRotationAlongTheShortestArc() throws {
        let quarterTurn = Quat(axis: [0, 1, 0], angle: .pi / 2)
        let animation = VoxelNodeAnimation(transformKeys: [key(0, position: .zero), key(10, position: .zero, rotation: quarterTurn)])

        let middle = try #require(animation.transform(at: 5)).rotation
        let expected = Quat(axis: [0, 1, 0], angle: .pi / 4)
        #expect(near(middle.x, expected.x) && near(middle.y, expected.y) && near(middle.z, expected.z) && near(middle.w, expected.w))

        // A negated quaternion encodes the same rotation; interpolation must not take the long way around.
        let negated = Quat(x: -quarterTurn.x, y: -quarterTurn.y, z: -quarterTurn.z, w: -quarterTurn.w)
        let other = VoxelNodeAnimation(transformKeys: [key(0, position: .zero), key(10, position: .zero, rotation: negated)])
        let shortArc = try #require(other.transform(at: 5)).rotation
        #expect(near(abs(shortArc.dot(expected)), 1))
    }

    @Test
    func switchesShapesWithoutInterpolation() throws {
        let animation = VoxelNodeAnimation(shapeKeys: [
            .init(frame: 4, meshIndex: 7, offset: [0, 0, 0]),
            .init(frame: 0, meshIndex: 3, offset: [1, 1, 1])
        ])

        #expect(animation.shape(at: 0)?.meshIndex == 3)
        #expect(animation.shape(at: 3.9)?.meshIndex == 3)
        #expect(animation.shape(at: 4)?.meshIndex == 7)
        #expect(animation.shape(at: 100)?.meshIndex == 7)
        #expect(VoxelNodeAnimation().shape(at: 1) == nil)
        #expect(VoxelNodeAnimation().transform(at: 1) == nil)
    }

    // MARK: - Clock

    @Test
    func clockWrapsWhenRepeating() {
        var playback = VoxelAnimationPlayback3DComponent(framesPerSecond: 10, frameCount: 11)

        playback.advance(by: 0.5)
        playback.advance(by: 0.5)
        #expect(near(playback.currentFrame, 10))
        playback.advance(by: 0.2)
        #expect(playback.time < 0.15 && playback.time > 0.05)
        #expect(playback.isPlaying)
    }

    @Test
    func clockStopsAtTheEndWhenNotRepeating() {
        var playback = VoxelAnimationPlayback3DComponent(framesPerSecond: 10, frameCount: 11, repeats: false)

        playback.advance(by: 5)
        #expect(!playback.isPlaying)
        #expect(near(playback.currentFrame, 11))
    }

    @Test
    func pausedClockDoesNotAdvance() {
        var playback = VoxelAnimationPlayback3DComponent(frameCount: 10, isPlaying: false)

        playback.advance(by: 1)
        #expect(playback.time == 0)
    }

    @Test
    func speedScalesTheClock() {
        var playback = VoxelAnimationPlayback3DComponent(framesPerSecond: 10, frameCount: 100, speed: 2)

        playback.advance(by: 1)
        #expect(near(playback.currentFrame, 20))
    }

    // MARK: - Import

    private func model(size: (Int, Int, Int)) -> VOXModel {
        VOXModel(sizeX: size.0, sizeY: size.1, sizeZ: size.2, voxels: [VOXVoxel(x: 0, y: 0, z: 0, colorIndex: 1)])
    }

    private func build(_ file: VOXFile) -> VoxelSceneBuilder.Result {
        VoxelSceneBuilder.build(
            file: file,
            options: VoxelImportOptions(voxelSize: 1, mergeStatic: true, bakesAmbientOcclusion: false)
        )
    }

    @Test
    func importsTransformKeysInEngineSpace() throws {
        let frames = [
            VOXTransformFrame(translation: SIMD3(1, 2, 3), frameIndex: 0),
            VOXTransformFrame(translation: SIMD3(1, 2, 13), frameIndex: 10)
        ]
        let file = VOXFile(
            models: [model(size: (1, 1, 1))],
            nodes: [
                0: .transform(VOXTransformNode(id: 0, childID: 1, frames: frames)),
                1: .shape(VOXShapeNode(id: 1, models: [.init(modelIndex: 0)]))
            ]
        )

        let result = build(file)
        let animated = try #require(result.nodes.first { $0.animation?.transformKeys.isEmpty == false })
        let keys = try #require(animated.animation).transformKeys

        #expect(keys.map(\.frame) == [0, 10])
        // MagicaVoxel (x, y, z) becomes engine (x, z, y).
        #expect(keys[0].transform.position == [1, 3, 2])
        #expect(keys[1].transform.position == [1, 13, 2])
        // Static siblings elsewhere are not animated.
        #expect(result.nodes.filter { $0.animation != nil }.count == 1)
    }

    @Test
    func importsShapeKeysWithPerModelPivotOffsets() throws {
        let file = VOXFile(
            models: [model(size: (1, 1, 1)), model(size: (3, 5, 7))],
            nodes: [
                0: .transform(VOXTransformNode(id: 0, childID: 1)),
                1: .shape(VOXShapeNode(id: 1, models: [.init(modelIndex: 0, frameIndex: 0), .init(modelIndex: 1, frameIndex: 5)]))
            ]
        )

        let result = build(file)
        let node = try #require(result.nodes.first { $0.animation?.shapeKeys.isEmpty == false })
        let keys = try #require(node.animation).shapeKeys

        #expect(keys.map(\.frame) == [0, 5])
        #expect(keys[0].offset == [0, 0, 0])
        // Pivot of the 3x5x7 model is (1, 2, 3); offsets are in engine space (Y and Z swapped).
        #expect(keys[1].offset == [-1, -3, -2])
        #expect(keys[0].meshIndex != keys[1].meshIndex)
        #expect(result.meshes.count == 2)
    }

    @Test
    func animatedPartsStayUnmergedAndStaticNodesCarryNoAnimation() throws {
        let animated = [VOXTransformFrame(frameIndex: 0), VOXTransformFrame(translation: SIMD3(0, 0, 4), frameIndex: 8)]
        let file = VOXFile(
            models: [model(size: (1, 1, 1))],
            nodes: [
                0: .transform(VOXTransformNode(id: 0, childID: 1)),
                1: .group(VOXGroupNode(id: 1, childIDs: [2, 4])),
                2: .transform(VOXTransformNode(id: 2, name: "arm", childID: 3, frames: animated)),
                3: .shape(VOXShapeNode(id: 3, models: [.init(modelIndex: 0)])),
                4: .transform(VOXTransformNode(id: 4, name: "body", childID: 5, frames: [VOXTransformFrame(translation: SIMD3(5, 0, 0))])),
                5: .shape(VOXShapeNode(id: 5, models: [.init(modelIndex: 0)]))
            ]
        )

        let result = build(file)
        #expect(result.nodes.first { $0.name == "arm" }?.animation != nil)
        #expect(result.nodes.first { $0.name == "body" }?.animation == nil)
        let lastFrame = result.nodes.compactMap { $0.animation?.lastFrame }.max()
        #expect(lastFrame == 8)
    }
}
