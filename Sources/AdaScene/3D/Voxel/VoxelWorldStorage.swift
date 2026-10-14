//
//  VoxelWorldStorage.swift
//  AdaEngine
//

import AdaAssets
import AdaECS
@_spi(Internal) import AdaRender
import Synchronization

/// Integer coordinate of a chunk in a voxel world.
public struct VoxelChunkCoordinate: Hashable, Sendable {
    public var x: Int
    public var y: Int
    public var z: Int

    public init(x: Int, y: Int, z: Int) {
        self.x = x
        self.y = y
        self.z = z
    }
}

/// Thread-safe chunked voxel storage. Voxel coordinates are integers in world space (X right, Y up, Z forward);
/// negative coordinates are allowed. Palette index `0` is empty space.
///
/// Edits mark the touched chunk, and neighbouring chunks when the voxel lies on a shared border, as dirty so
/// ``VoxelWorldMeshing3DSystem`` can rebuild their meshes.
public final class VoxelWorldStorage: Sendable {
    /// Edge length of a chunk in voxels.
    public static let chunkSize = 32

    private struct State {
        var chunks: [VoxelChunkCoordinate: [UInt8]] = [:]
        var dirty: [VoxelChunkCoordinate] = []
        var dirtySet: Set<VoxelChunkCoordinate> = []
        var chunkEntities: [VoxelChunkCoordinate: Entity.ID] = [:]
    }

    private let state = Mutex(State())

    public init() {}

    // MARK: - Coordinates

    /// The chunk containing a voxel, and the voxel's position inside it.
    public static func locate(x: Int, y: Int, z: Int) -> (chunk: VoxelChunkCoordinate, local: SIMD3<Int>) {
        func split(_ value: Int) -> (Int, Int) {
            let chunk = value >= 0 ? value / chunkSize : -((-value + chunkSize - 1) / chunkSize)
            return (chunk, value - chunk * chunkSize)
        }
        let (cx, lx) = split(x)
        let (cy, ly) = split(y)
        let (cz, lz) = split(z)
        return (VoxelChunkCoordinate(x: cx, y: cy, z: cz), SIMD3(lx, ly, lz))
    }

    private static func index(_ local: SIMD3<Int>) -> Int {
        (local.z * chunkSize + local.y) * chunkSize + local.x
    }

    // MARK: - Reading

    public func voxel(x: Int, y: Int, z: Int) -> UInt8 {
        let (chunk, local) = Self.locate(x: x, y: y, z: z)
        return state.withLock { $0.chunks[chunk]?[Self.index(local)] ?? 0 }
    }

    public func isSolid(x: Int, y: Int, z: Int) -> Bool {
        voxel(x: x, y: y, z: z) != 0
    }

    /// Coordinates of all chunks that currently hold voxels.
    public var chunkCoordinates: [VoxelChunkCoordinate] {
        state.withLock { Array($0.chunks.keys) }
    }

    public var solidCount: Int {
        state.withLock { state in
            state.chunks.values.reduce(0) { total, cells in total + cells.reduce(0) { $0 + ($1 == 0 ? 0 : 1) } }
        }
    }

    // MARK: - Writing

    /// Sets a voxel. Returns `true` when the voxel changed.
    @discardableResult
    public func setVoxel(x: Int, y: Int, z: Int, color: UInt8) -> Bool {
        let (chunk, local) = Self.locate(x: x, y: y, z: z)
        return state.withLock { state in
            Self.set(&state, chunk: chunk, local: local, color: color)
        }
    }

    /// Writes a dense grid with its minimum corner at `origin`. Empty cells of the grid clear existing voxels
    /// unless `skipsEmpty` is `true`.
    public func stamp(_ grid: VoxelGrid, at origin: SIMD3<Int>, skipsEmpty: Bool = true) {
        state.withLock { state in
            for z in 0..<grid.sizeZ {
                for y in 0..<grid.sizeY {
                    for x in 0..<grid.sizeX {
                        let color = grid[x, y, z]
                        if skipsEmpty, color == 0 {
                            continue
                        }
                        let (chunk, local) = Self.locate(x: origin.x + x, y: origin.y + y, z: origin.z + z)
                        Self.set(&state, chunk: chunk, local: local, color: color)
                    }
                }
            }
        }
    }

    /// Fills an inclusive box with one color (`0` clears it).
    public func fill(from lower: SIMD3<Int>, to upper: SIMD3<Int>, color: UInt8) {
        state.withLock { state in
            for z in lower.z...max(lower.z, upper.z) {
                for y in lower.y...max(lower.y, upper.y) {
                    for x in lower.x...max(lower.x, upper.x) {
                        let (chunk, local) = Self.locate(x: x, y: y, z: z)
                        Self.set(&state, chunk: chunk, local: local, color: color)
                    }
                }
            }
        }
    }

    @discardableResult
    private static func set(_ state: inout State, chunk: VoxelChunkCoordinate, local: SIMD3<Int>, color: UInt8) -> Bool {
        let index = Self.index(local)
        let current = state.chunks[chunk]?[index] ?? 0
        guard current != color else {
            return false
        }

        if state.chunks[chunk] == nil {
            state.chunks[chunk] = [UInt8](repeating: 0, count: chunkSize * chunkSize * chunkSize)
        }
        state.chunks[chunk]?[index] = color

        // A voxel on a chunk border changes faces and occlusion in every neighbouring chunk it touches, including
        // diagonal neighbours across edges and corners.
        func offsets(_ value: Int) -> [Int] {
            var result = [0]
            if value == 0 {
                result.append(-1)
            }
            if value == chunkSize - 1 {
                result.append(1)
            }
            return result
        }
        for dx in offsets(local.x) {
            for dy in offsets(local.y) {
                for dz in offsets(local.z) {
                    markDirty(&state, VoxelChunkCoordinate(x: chunk.x + dx, y: chunk.y + dy, z: chunk.z + dz))
                }
            }
        }
        return true
    }

    private static func markDirty(_ state: inout State, _ chunk: VoxelChunkCoordinate) {
        if state.dirtySet.insert(chunk).inserted {
            state.dirty.append(chunk)
        }
    }

    // MARK: - Meshing support

    /// Whether any chunk waits for remeshing.
    public var hasDirtyChunks: Bool {
        state.withLock { !$0.dirty.isEmpty }
    }

    /// Removes and returns up to `limit` dirty chunks, oldest first.
    public func takeDirtyChunks(limit: Int) -> [VoxelChunkCoordinate] {
        state.withLock { state in
            let taken = Array(state.dirty.prefix(max(0, limit)))
            state.dirty.removeFirst(taken.count)
            state.dirtySet.subtract(taken)
            return taken
        }
    }

    /// Marks every chunk dirty, for example after the palette or voxel size changed.
    public func invalidateAll() {
        state.withLock { state in
            for chunk in state.chunks.keys {
                Self.markDirty(&state, chunk)
            }
            for chunk in state.chunkEntities.keys {
                Self.markDirty(&state, chunk)
            }
        }
    }

    /// A copy of a chunk padded with one voxel of its neighbours on every side, and the region to mesh.
    public func paddedSnapshot(of chunk: VoxelChunkCoordinate) -> (grid: VoxelGrid, region: VoxelMeshingRegion) {
        let size = Self.chunkSize
        var grid = VoxelGrid(sizeX: size + 2, sizeY: size + 2, sizeZ: size + 2)
        state.withLock { state in
            for dz in -1...1 {
                for dy in -1...1 {
                    for dx in -1...1 {
                        let neighbor = VoxelChunkCoordinate(x: chunk.x + dx, y: chunk.y + dy, z: chunk.z + dz)
                        guard let cells = state.chunks[neighbor] else {
                            continue
                        }
                        // Overlap of the neighbour chunk with the padded box, in the neighbour's local coordinates.
                        func range(_ delta: Int) -> ClosedRange<Int> {
                            delta < 0 ? (size - 1)...(size - 1) : (delta > 0 ? 0...0 : 0...(size - 1))
                        }
                        for lz in range(dz) {
                            for ly in range(dy) {
                                for lx in range(dx) {
                                    let color = cells[Self.index(SIMD3(lx, ly, lz))]
                                    if color != 0 {
                                        grid[lx + dx * size + 1, ly + dy * size + 1, lz + dz * size + 1] = color
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return (grid, VoxelMeshingRegion(origin: SIMD3(1, 1, 1), size: SIMD3(size, size, size)))
    }

    // MARK: - Chunk entities

    public func chunkEntity(for chunk: VoxelChunkCoordinate) -> Entity.ID? {
        state.withLock { $0.chunkEntities[chunk] }
    }

    public func setChunkEntity(_ entity: Entity.ID?, for chunk: VoxelChunkCoordinate) {
        state.withLock { $0.chunkEntities[chunk] = entity }
    }

    public var chunkEntities: [VoxelChunkCoordinate: Entity.ID] {
        state.withLock { $0.chunkEntities }
    }

    /// Drops chunks that contain no voxels.
    public func removeEmptyChunks() {
        state.withLock { state in
            state.chunks = state.chunks.filter { $0.value.contains { $0 != 0 } }
        }
    }
}
