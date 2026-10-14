//
//  VoxelGrid.swift
//  AdaEngine
//

import AdaAssets

/// A dense grid of palette indices. Index `0` is empty space, `1...255` map to palette entries.
public struct VoxelGrid: Sendable {
    public let sizeX: Int
    public let sizeY: Int
    public let sizeZ: Int
    private var cells: [UInt8]

    /// Creates an empty grid.
    public init(sizeX: Int, sizeY: Int, sizeZ: Int) {
        precondition(sizeX >= 0 && sizeY >= 0 && sizeZ >= 0, "Grid dimensions must not be negative")
        self.sizeX = sizeX
        self.sizeY = sizeY
        self.sizeZ = sizeZ
        self.cells = [UInt8](repeating: 0, count: sizeX * sizeY * sizeZ)
    }

    /// Creates a grid from a sparse MagicaVoxel model. Voxels outside the model bounds are ignored.
    public init(model: VOXModel) {
        self.init(sizeX: model.sizeX, sizeY: model.sizeY, sizeZ: model.sizeZ)
        for voxel in model.voxels {
            self[Int(voxel.x), Int(voxel.y), Int(voxel.z)] = voxel.colorIndex
        }
    }

    /// The number of non-empty voxels.
    public var solidCount: Int {
        cells.reduce(0) { $0 + ($1 == 0 ? 0 : 1) }
    }

    /// Palette index at the given coordinates. Out-of-bounds reads return `0` (empty); out-of-bounds writes are ignored.
    public subscript(x: Int, y: Int, z: Int) -> UInt8 {
        get {
            guard contains(x, y, z) else {
                return 0
            }
            return cells[index(x, y, z)]
        }
        set {
            guard contains(x, y, z) else {
                return
            }
            cells[index(x, y, z)] = newValue
        }
    }

    public func isSolid(_ x: Int, _ y: Int, _ z: Int) -> Bool {
        self[x, y, z] != 0
    }

    private func contains(_ x: Int, _ y: Int, _ z: Int) -> Bool {
        x >= 0 && y >= 0 && z >= 0 && x < sizeX && y < sizeY && z < sizeZ
    }

    private func index(_ x: Int, _ y: Int, _ z: Int) -> Int {
        (z * sizeY + y) * sizeX + x
    }
}
