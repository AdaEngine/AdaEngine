import AdaAssets
import AdaPhysics
import Math
import Testing
@_spi(Internal) import AdaRender
@testable import AdaScene

@Suite
struct VoxelPhysicsTests {
    private func grid(_ size: (Int, Int, Int), solid: [(Int, Int, Int)]) -> VoxelGrid {
        var grid = VoxelGrid(sizeX: size.0, sizeY: size.1, sizeZ: size.2)
        for cell in solid {
            grid[cell.0, cell.1, cell.2] = 1
        }
        return grid
    }

    // MARK: - Box merging

    @Test
    func solidBlockBecomesOneBox() {
        let solid = grid((4, 3, 2), solid: (0..<2).flatMap { z in (0..<3).flatMap { y in (0..<4).map { x in (x, y, z) } } })

        let boxes = VoxelColliderBuilder.boxes(in: solid)
        #expect(boxes == [VoxelBox(origin: .zero, size: SIMD3(4, 3, 2))])
    }

    @Test
    func emptyGridHasNoBoxes() {
        #expect(VoxelColliderBuilder.boxes(in: VoxelGrid(sizeX: 3, sizeY: 3, sizeZ: 3)).isEmpty)
        #expect(VoxelColliderBuilder.boxes(in: VoxelGrid(sizeX: 0, sizeY: 0, sizeZ: 0)).isEmpty)
    }

    @Test
    func lShapeIsCoveredExactlyOnce() {
        let shape = grid((3, 3, 1), solid: [(0, 0, 0), (1, 0, 0), (2, 0, 0), (0, 1, 0), (0, 2, 0)])

        let boxes = VoxelColliderBuilder.boxes(in: shape)
        #expect(boxes.map(\.volume).reduce(0, +) == 5)
        #expect(boxes.count == 2)
    }

    @Test
    func boxesCoverExactlyTheSolidVoxelsOfRandomGrids() {
        var generator = SplitMix(seed: 0xC0FFEE)
        for _ in 0..<20 {
            let size = (Int.random(in: 1...6, using: &generator), Int.random(in: 1...6, using: &generator), Int.random(in: 1...6, using: &generator))
            var cells: [(Int, Int, Int)] = []
            for z in 0..<size.2 {
                for y in 0..<size.1 {
                    for x in 0..<size.0 where Int.random(in: 0..<100, using: &generator) < 60 {
                        cells.append((x, y, z))
                    }
                }
            }
            let source = grid(size, solid: cells)

            var covered = Set<SIMD3<Int>>()
            var overlaps = 0
            for box in VoxelColliderBuilder.boxes(in: source) {
                for z in 0..<box.size.z {
                    for y in 0..<box.size.y {
                        for x in 0..<box.size.x {
                            let cell = box.origin &+ SIMD3(x, y, z)
                            #expect(source.isSolid(cell.x, cell.y, cell.z))
                            overlaps += covered.insert(cell).inserted ? 0 : 1
                        }
                    }
                }
            }
            #expect(overlaps == 0)
            #expect(covered.count == source.solidCount)
        }
    }

    @Test
    func regionBoxesAreRelativeToTheRegionOrigin() {
        let source = grid((4, 1, 1), solid: [(0, 0, 0), (1, 0, 0), (2, 0, 0), (3, 0, 0)])

        let boxes = VoxelColliderBuilder.boxes(in: source, region: VoxelMeshingRegion(origin: SIMD3(1, 0, 0), size: SIMD3(2, 1, 1)))
        #expect(boxes == [VoxelBox(origin: .zero, size: SIMD3(2, 1, 1))])
    }

    @Test
    func shapesAreScaledAndCentered() throws {
        let shapes = VoxelColliderBuilder.shapes(for: [VoxelBox(origin: SIMD3(2, 0, 0), size: SIMD3(2, 4, 2))], voxelSize: 0.5)

        // Box from x 2...4, y 0...4, z 0...2 cells: center (3, 2, 1) cells = (1.5, 1, 0.5) units, size (1, 2, 1).
        #expect(shapes == [Shape3DResource.generateBox(width: 1, height: 2, depth: 1, center: [1.5, 1, 0.5])])

        let shifted = VoxelColliderBuilder.shapes(for: [VoxelBox(origin: .zero, size: SIMD3(2, 2, 2))], voxelSize: 1, offset: [1, 1, 1])
        #expect(shifted == [Shape3DResource.generateBox(width: 2, height: 2, depth: 2, center: .zero)])
    }

    // MARK: - Islands

    private func column(_ storage: VoxelWorldStorage, x: Int = 0, z: Int = 0, from lower: Int, to upper: Int) {
        for y in lower...upper {
            storage.setVoxel(x: x, y: y, z: z, color: 1)
        }
    }

    @Test
    func cuttingATowerDetachesItsTop() throws {
        let storage = VoxelWorldStorage()
        column(storage, from: 0, to: 7)
        storage.setVoxel(x: 0, y: 3, z: 0, color: 0)

        let islands = storage.detachFloatingIslands(around: [SIMD3(0, 3, 0)], isAnchored: { $0.y <= 0 })

        let island = try #require(islands.first)
        #expect(islands.count == 1)
        #expect(island.voxelCount == 4)
        #expect(island.origin == SIMD3(0, 4, 0))
        #expect((island.grid.sizeX, island.grid.sizeY, island.grid.sizeZ) == (1, 4, 1))
        // The island leaves the world; the anchored base stays.
        #expect(storage.voxel(x: 0, y: 5, z: 0) == 0)
        #expect(storage.voxel(x: 0, y: 2, z: 0) == 1)
        #expect(storage.solidCount == 3)
    }

    @Test
    func islandsKeepVoxelColors() throws {
        let storage = VoxelWorldStorage()
        column(storage, from: 0, to: 3)
        storage.setVoxel(x: 0, y: 3, z: 0, color: 9)
        storage.setVoxel(x: 0, y: 1, z: 0, color: 0)

        let island = try #require(storage.detachFloatingIslands(around: [SIMD3(0, 1, 0)], isAnchored: { $0.y <= 0 }).first)
        #expect(island.grid[0, 0, 0] == 1)
        #expect(island.grid[0, 1, 0] == 9)
    }

    @Test
    func structuresStillConnectedToTheGroundStay() {
        let storage = VoxelWorldStorage()
        // An arch: two legs and a bridge on top. Removing one bridge voxel keeps both halves attached to their legs.
        column(storage, x: 0, from: 0, to: 4)
        column(storage, x: 4, from: 0, to: 4)
        for x in 0...4 {
            storage.setVoxel(x: x, y: 5, z: 0, color: 1)
        }
        storage.setVoxel(x: 2, y: 5, z: 0, color: 0)

        let islands = storage.detachFloatingIslands(around: [SIMD3(2, 5, 0)], isAnchored: { $0.y <= 0 })
        #expect(islands.isEmpty)
        #expect(storage.voxel(x: 1, y: 5, z: 0) == 1)
    }

    @Test
    func oversizedComponentsAreTreatedAsAnchored() {
        let storage = VoxelWorldStorage()
        column(storage, from: 0, to: 20)
        storage.setVoxel(x: 0, y: 2, z: 0, color: 0)

        // 18 voxels float above the cut, more than the limit of 10.
        #expect(storage.detachFloatingIslands(around: [SIMD3(0, 2, 0)], isAnchored: { $0.y <= 0 }, maxVoxels: 10).isEmpty)
        #expect(storage.voxel(x: 0, y: 10, z: 0) == 1)
    }

    @Test
    func twoSeparateIslandsDetachTogether() {
        let storage = VoxelWorldStorage()
        column(storage, x: 0, from: 0, to: 5)
        column(storage, x: 10, from: 0, to: 6)
        storage.setVoxel(x: 0, y: 2, z: 0, color: 0)
        storage.setVoxel(x: 10, y: 2, z: 0, color: 0)

        let islands = storage.detachFloatingIslands(around: [SIMD3(0, 2, 0), SIMD3(10, 2, 0)], isAnchored: { $0.y <= 0 })
        #expect(islands.map(\.voxelCount).sorted() == [3, 4])
    }

    @Test
    func detachingMarksChunksDirty() {
        let storage = VoxelWorldStorage()
        column(storage, from: 0, to: 5)
        storage.setVoxel(x: 0, y: 2, z: 0, color: 0)
        _ = storage.takeDirtyChunks(limit: 100)

        _ = storage.detachFloatingIslands(around: [SIMD3(0, 2, 0)], isAnchored: { $0.y <= 0 })
        #expect(storage.hasDirtyChunks)
    }

    @Test
    func islandsFloodAcrossChunkBorders() throws {
        let storage = VoxelWorldStorage()
        // A horizontal bar crossing the x = 31 / 32 chunk border, connected to nothing.
        for x in 28...36 {
            storage.setVoxel(x: x, y: 10, z: 10, color: 1)
        }
        storage.setVoxel(x: 27, y: 10, z: 10, color: 1)
        storage.setVoxel(x: 27, y: 10, z: 10, color: 0)

        let island = try #require(storage.detachFloatingIslands(around: [SIMD3(27, 10, 10)], isAnchored: { _ in false }).first)
        #expect(island.voxelCount == 9)
        #expect(island.origin == SIMD3(28, 10, 10))
    }
}

/// A small deterministic generator for reproducible randomized tests.
private struct SplitMix: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
