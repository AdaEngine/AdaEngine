import AdaAssets
import Testing
@_spi(Internal) import AdaRender
@testable import AdaScene

@Suite
struct VoxelWorldStorageTests {
    private typealias Coordinate = VoxelChunkCoordinate

    @Test
    func locatesChunksForNegativeCoordinates() {
        func locate(_ x: Int) -> (Int, Int) {
            let result = VoxelWorldStorage.locate(x: x, y: 0, z: 0)
            return (result.chunk.x, result.local.x)
        }

        #expect(locate(0) == (0, 0))
        #expect(locate(31) == (0, 31))
        #expect(locate(32) == (1, 0))
        #expect(locate(-1) == (-1, 31))
        #expect(locate(-32) == (-1, 0))
        #expect(locate(-33) == (-2, 31))
    }

    @Test
    func readsBackWrittenVoxelsAcrossChunks() {
        let storage = VoxelWorldStorage()

        #expect(storage.setVoxel(x: -1, y: 0, z: 0, color: 3))
        #expect(storage.setVoxel(x: 32, y: 40, z: -70, color: 9))
        #expect(!storage.setVoxel(x: 32, y: 40, z: -70, color: 9))

        #expect(storage.voxel(x: -1, y: 0, z: 0) == 3)
        #expect(storage.voxel(x: 32, y: 40, z: -70) == 9)
        #expect(storage.voxel(x: 5, y: 5, z: 5) == 0)
        #expect(storage.isSolid(x: -1, y: 0, z: 0))
        #expect(storage.solidCount == 2)
        #expect(Set(storage.chunkCoordinates) == [Coordinate(x: -1, y: 0, z: 0), Coordinate(x: 1, y: 1, z: -3)])

        storage.setVoxel(x: -1, y: 0, z: 0, color: 0)
        #expect(storage.solidCount == 1)
    }

    @Test
    func interiorEditsDirtyOnlyTheirChunk() {
        let storage = VoxelWorldStorage()
        storage.setVoxel(x: 10, y: 10, z: 10, color: 1)

        #expect(storage.takeDirtyChunks(limit: 10) == [Coordinate(x: 0, y: 0, z: 0)])
        #expect(!storage.hasDirtyChunks)
    }

    @Test
    func borderEditsDirtyNeighbouringChunks() {
        let storage = VoxelWorldStorage()

        storage.setVoxel(x: 0, y: 5, z: 5, color: 1)
        #expect(Set(storage.takeDirtyChunks(limit: 10)) == [Coordinate(x: 0, y: 0, z: 0), Coordinate(x: -1, y: 0, z: 0)])

        // A voxel in a corner touches the chunk itself, three face, three edge and one corner neighbour.
        storage.setVoxel(x: 0, y: 0, z: 0, color: 1)
        let corner = storage.takeDirtyChunks(limit: 100)
        #expect(corner.count == 8)
        #expect(corner.contains(Coordinate(x: -1, y: -1, z: -1)))
        #expect(corner.contains(Coordinate(x: -1, y: -1, z: 0)))
    }

    @Test
    func takingDirtyChunksRespectsTheLimitAndOrder() {
        let storage = VoxelWorldStorage()
        for index in 0..<5 {
            storage.setVoxel(x: index * 64 + 10, y: 10, z: 10, color: 1)
        }

        #expect(storage.takeDirtyChunks(limit: 2) == [Coordinate(x: 0, y: 0, z: 0), Coordinate(x: 2, y: 0, z: 0)])
        #expect(storage.hasDirtyChunks)
        #expect(storage.takeDirtyChunks(limit: 100).count == 3)
        #expect(!storage.hasDirtyChunks)
        #expect(storage.takeDirtyChunks(limit: 0).isEmpty)
    }

    @Test
    func unchangedWritesAreNotDirty() {
        let storage = VoxelWorldStorage()
        storage.setVoxel(x: 1, y: 1, z: 1, color: 4)
        _ = storage.takeDirtyChunks(limit: 10)

        storage.setVoxel(x: 1, y: 1, z: 1, color: 4)
        #expect(!storage.hasDirtyChunks)
    }

    @Test
    func paddedSnapshotIncludesNeighbourBorders() {
        let storage = VoxelWorldStorage()
        let chunk = Coordinate(x: 0, y: 0, z: 0)
        storage.setVoxel(x: 0, y: 0, z: 0, color: 1)
        // One voxel in each kind of neighbour that touches the padding.
        storage.setVoxel(x: -1, y: 5, z: 5, color: 2)
        storage.setVoxel(x: 32, y: 5, z: 5, color: 3)
        storage.setVoxel(x: -1, y: -1, z: -1, color: 4)
        storage.setVoxel(x: 32, y: 32, z: 32, color: 5)
        // Too far away to be visible.
        storage.setVoxel(x: -2, y: 5, z: 5, color: 6)

        let snapshot = storage.paddedSnapshot(of: chunk)
        let size = VoxelWorldStorage.chunkSize

        #expect(snapshot.grid.sizeX == size + 2)
        #expect(snapshot.region == VoxelMeshingRegion(origin: SIMD3(1, 1, 1), size: SIMD3(size, size, size)))
        #expect(snapshot.grid[1, 1, 1] == 1)
        #expect(snapshot.grid[0, 6, 6] == 2)
        #expect(snapshot.grid[size + 1, 6, 6] == 3)
        #expect(snapshot.grid[0, 0, 0] == 4)
        #expect(snapshot.grid[size + 1, size + 1, size + 1] == 5)
        #expect(snapshot.grid.solidCount == 5)
    }

    @Test
    func stampsGridsAtNegativeOrigins() {
        let storage = VoxelWorldStorage()
        var grid = VoxelGrid(sizeX: 3, sizeY: 1, sizeZ: 1)
        grid[0, 0, 0] = 7
        grid[2, 0, 0] = 8

        storage.stamp(grid, at: SIMD3(-2, 4, 10))

        #expect(storage.voxel(x: -2, y: 4, z: 10) == 7)
        #expect(storage.voxel(x: -1, y: 4, z: 10) == 0)
        #expect(storage.voxel(x: 0, y: 4, z: 10) == 8)
        #expect(Set(storage.takeDirtyChunks(limit: 10)) == [Coordinate(x: -1, y: 0, z: 0), Coordinate(x: 0, y: 0, z: 0)])
    }

    @Test
    func fillsBoxesAndClearsThem() {
        let storage = VoxelWorldStorage()

        storage.fill(from: SIMD3(-1, 0, 0), to: SIMD3(1, 1, 1), color: 2)
        #expect(storage.solidCount == 3 * 2 * 2)

        storage.fill(from: SIMD3(-1, 0, 0), to: SIMD3(1, 1, 1), color: 0)
        #expect(storage.solidCount == 0)
        storage.removeEmptyChunks()
        #expect(storage.chunkCoordinates.isEmpty)
    }

    @Test
    func storageIsSafeToEditFromManyThreads() async {
        let storage = VoxelWorldStorage()

        await withTaskGroup(of: Void.self) { group in
            for task in 0..<8 {
                group.addTask {
                    for index in 0..<200 {
                        storage.setVoxel(x: task * 50 + index % 50, y: index / 50, z: task, color: 1)
                    }
                }
            }
        }

        #expect(storage.solidCount == 8 * 200)
    }
}
