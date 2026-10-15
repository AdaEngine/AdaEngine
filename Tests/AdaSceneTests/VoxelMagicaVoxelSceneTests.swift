import AdaAssets
import Foundation
import Math
import Testing
@_spi(Internal) import AdaRender
@testable import AdaScene

/// Scene import of files saved by MagicaVoxel itself; see `Tests/AdaAssetsTests/Fixtures/vox/magicavoxel/README.md`.
@Suite
struct VoxelMagicaVoxelSceneTests {
    private func load(_ name: String) async throws -> VOXFile {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AdaAssetsTests/Fixtures/vox/magicavoxel/\(name).vox")
        return try await VOXLoader().load(url: url)
    }

    private func build(_ file: VOXFile) -> VoxelSceneBuilder.Result {
        VoxelSceneBuilder.build(
            file: file,
            options: VoxelImportOptions(voxelSize: 1, mergeStatic: false, bakesAmbientOcclusion: false)
        )
    }

    private func apply(_ matrix: Transform3D, to point: Vector3) -> Vector3 {
        Vector3(
            matrix.x.x * point.x + matrix.y.x * point.y + matrix.z.x * point.z + matrix.w.x,
            matrix.x.y * point.x + matrix.y.y * point.y + matrix.z.y * point.z + matrix.w.y,
            matrix.x.z * point.x + matrix.y.z * point.y + matrix.z.z * point.z + matrix.w.z
        )
    }

    /// Engine-space bounds of the geometry of each mesh index, in the scene.
    private func boundsByMesh(_ result: VoxelSceneBuilder.Result) -> [Int: (min: Vector3, max: Vector3)] {
        var bounds: [Int: (min: Vector3, max: Vector3)] = [:]
        func visit(_ index: Int, parent: Transform3D) {
            let node = result.nodes[index]
            let world = parent * node.transform
            if let meshIndex = node.meshIndex {
                for position in result.meshes[meshIndex].positions.elements {
                    let point = apply(world, to: position)
                    if let current = bounds[meshIndex] {
                        bounds[meshIndex] = (
                            Vector3(min(current.min.x, point.x), min(current.min.y, point.y), min(current.min.z, point.z)),
                            Vector3(max(current.max.x, point.x), max(current.max.y, point.y), max(current.max.z, point.z))
                        )
                    } else {
                        bounds[meshIndex] = (point, point)
                    }
                }
            }
            for child in node.children {
                visit(child, parent: world)
            }
        }
        visit(result.rootNodeIndex, parent: .identity)
        return bounds
    }

    /// Voxel extents of a model along its own X, Y and Z.
    private func extents(of model: VOXModel) -> SIMD3<Int> {
        let xs = model.voxels.map { Int($0.x) }
        let ys = model.voxels.map { Int($0.y) }
        let zs = model.voxels.map { Int($0.z) }
        return SIMD3(
            (xs.max() ?? 0) - (xs.min() ?? 0) + 1,
            (ys.max() ?? 0) - (ys.min() ?? 0) + 1,
            (zs.max() ?? 0) - (zs.min() ?? 0) + 1
        )
    }

    @Test
    func standsTheKnightOnTheGround() async throws {
        let file = try await load("chr_knight")
        let bounds = try #require(boundsByMesh(build(file))[0])
        let model = try #require(file.models.first)
        let size = extents(of: model)

        // MagicaVoxel Z (up) becomes Y: the lowest voxel sits at height 0 and the extents carry over with Y and Z swapped.
        #expect(bounds.min.y == 0)
        #expect(Int(bounds.max.x - bounds.min.x) == size.x)
        #expect(Int(bounds.max.y - bounds.min.y) == size.z)
        #expect(Int(bounds.max.z - bounds.min.z) == size.y)
    }

    @Test
    func placesTheTwoCarsAsAuthored() async throws {
        let file = try await load("cars")
        let result = build(file)
        let bounds = boundsByMesh(result)
        let police = try #require(bounds[0])
        let wagon = try #require(bounds[1])
        let policeSize = extents(of: file.models[0])
        let wagonSize = extents(of: file.models[1])

        // The police car was turned a quarter turn about Z: its long (Y) side now runs along X, and the wagon's still runs along Y.
        #expect(Int(police.max.x - police.min.x) == policeSize.y)
        #expect(Int(police.max.z - police.min.z) == policeSize.x)
        #expect(Int(wagon.max.x - wagon.min.x) == wagonSize.x)
        #expect(Int(wagon.max.z - wagon.min.z) == wagonSize.y)
        // Both stand on the ground.
        #expect(police.min.y == 0)
        #expect(wagon.min.y == 0)
        // The police car is authored left of the wagon (translations x = -28 and 16), without overlap.
        #expect(police.max.x < wagon.min.x)
    }

    @Test
    func keysEachDeerFrame() async throws {
        let file = try await load("deer")
        let result = build(file)

        let node = try #require(result.nodes.first { $0.animation?.shapeKeys.isEmpty == false })
        let keys = try #require(node.animation).shapeKeys
        #expect(keys.map(\.frame) == [0, 1, 2, 3])
        #expect(Set(keys.map(\.meshIndex)).count == 4)
        // All four models share one size, hence one pivot offset: -(13, 4, 13) in MagicaVoxel space, Y and Z swapped.
        #expect(keys.allSatisfy { $0.offset == Vector3(-13, -13, -4) })
        #expect(result.meshes.count == 4)
    }
}
