//
//  VoxelMesher.swift
//  AdaEngine
//

import AdaAssets
import AdaUtils
import Math

/// Options controlling how a voxel grid is converted to a mesh.
public struct VoxelMeshingOptions: Sendable {
    public enum Strategy: Sendable {
        /// One quad per exposed voxel face.
        case culled
        /// Merges coplanar neighbouring faces that share color and flat lighting.
        case greedy
    }

    /// Edge length of one voxel in world units.
    public var voxelSize: Float
    public var strategy: Strategy
    /// Bakes per-vertex ambient occlusion into the vertex colors.
    public var bakesAmbientOcclusion: Bool

    public init(voxelSize: Float = 0.1, strategy: Strategy = .greedy, bakesAmbientOcclusion: Bool = true) {
        self.voxelSize = voxelSize
        self.strategy = strategy
        self.bakesAmbientOcclusion = bakesAmbientOcclusion
    }
}

/// A sub-box of a ``VoxelGrid`` to mesh. Voxels outside the box still count as neighbours for face culling and
/// ambient occlusion, so chunks can be meshed from a grid padded with a border of adjacent voxels.
public struct VoxelMeshingRegion: Sendable, Equatable {
    public var origin: SIMD3<Int>
    public var size: SIMD3<Int>

    public init(origin: SIMD3<Int>, size: SIMD3<Int>) {
        self.origin = origin
        self.size = size
    }
}

/// Converts voxel grids to triangle meshes on the CPU.
///
/// The mesh stays in grid space (the minimum corner of voxel `(0, 0, 0)` is the origin) scaled by
/// `voxelSize`. Axis conversion and pivots belong to scene import. Every non-empty voxel is treated
/// as opaque for face culling, regardless of palette alpha.
public enum VoxelMesher {
    /// Brightness applied to vertex colors for ambient occlusion levels `0...3` (darkest to unoccluded).
    static let ambientOcclusionBrightness: [Float] = [0.55, 0.7, 0.85, 1.0]

    /// Builds a mesh descriptor, or `nil` when the grid has no exposed faces.
    ///
    /// When `region` is given only voxels inside it produce faces, and positions are relative to the region's
    /// minimum corner.
    public static func makeDescriptor(
        grid: VoxelGrid,
        palette: VOXPalette,
        options: VoxelMeshingOptions = VoxelMeshingOptions(),
        region: VoxelMeshingRegion? = nil,
        name: String = "VoxelMesh"
    ) -> MeshDescriptor? {
        var builder = MeshBuilder(options: options, palette: palette)
        let region = region ?? VoxelMeshingRegion(origin: .zero, size: SIMD3(grid.sizeX, grid.sizeY, grid.sizeZ))
        let dimensions = [region.size.x, region.size.y, region.size.z]

        for axis in 0..<3 {
            for isPositive in [true, false] {
                let uAxis = (axis + 1) % 3
                let vAxis = (axis + 2) % 3
                let width = dimensions[uAxis]
                let height = dimensions[vAxis]
                guard width > 0, height > 0 else {
                    continue
                }

                var mask = [UInt32](repeating: 0, count: width * height)
                for layer in 0..<dimensions[axis] {
                    fillMask(
                        &mask,
                        grid: grid,
                        origin: region.origin,
                        axis: axis,
                        isPositive: isPositive,
                        layer: layer,
                        width: width,
                        height: height,
                        bakesAmbientOcclusion: options.bakesAmbientOcclusion
                    )
                    emitQuads(
                        &mask,
                        builder: &builder,
                        axis: axis,
                        isPositive: isPositive,
                        layer: layer,
                        width: width,
                        height: height
                    )
                }
            }
        }

        return builder.makeDescriptor(name: name)
    }

    // MARK: - Mask

    /// Mask cell layout: bits 0-7 palette index, bits 8-15 four 2-bit ambient occlusion levels. `0` means no face.
    private static func fillMask(
        _ mask: inout [UInt32],
        grid: VoxelGrid,
        origin: SIMD3<Int>,
        axis: Int,
        isPositive: Bool,
        layer: Int,
        width: Int,
        height: Int,
        bakesAmbientOcclusion: Bool
    ) {
        let uAxis = (axis + 1) % 3
        let vAxis = (axis + 2) % 3
        let step = isPositive ? 1 : -1

        for j in 0..<height {
            for i in 0..<width {
                var position = origin
                position[axis] += layer
                position[uAxis] += i
                position[vAxis] += j

                let color = grid[position.x, position.y, position.z]
                var neighbor = position
                neighbor[axis] += step
                guard color != 0, !grid.isSolid(neighbor.x, neighbor.y, neighbor.z) else {
                    mask[j * width + i] = 0
                    continue
                }

                var key = UInt32(color)
                let levels = bakesAmbientOcclusion
                    ? cornerOcclusion(grid: grid, neighbor: neighbor, uAxis: uAxis, vAxis: vAxis)
                    : [3, 3, 3, 3]
                for (corner, level) in levels.enumerated() {
                    key |= UInt32(level) << UInt32(8 + corner * 2)
                }
                mask[j * width + i] = key
            }
        }
    }

    /// Occlusion levels for the four face corners ordered (-u,-v), (+u,-v), (+u,+v), (-u,+v).
    private static func cornerOcclusion(grid: VoxelGrid, neighbor: SIMD3<Int>, uAxis: Int, vAxis: Int) -> [UInt8] {
        let corners: [(Int, Int)] = [(-1, -1), (1, -1), (1, 1), (-1, 1)]

        func isSolid(du: Int, dv: Int) -> Bool {
            var position = neighbor
            position[uAxis] += du
            position[vAxis] += dv
            return grid.isSolid(position.x, position.y, position.z)
        }

        return corners.map { corner in
            let side1 = isSolid(du: corner.0, dv: 0)
            let side2 = isSolid(du: 0, dv: corner.1)
            if side1, side2 {
                return 0
            }
            let diagonal = isSolid(du: corner.0, dv: corner.1)
            return UInt8(3 - (side1 ? 1 : 0) - (side2 ? 1 : 0) - (diagonal ? 1 : 0))
        }
    }

    /// A face can merge only when all four corners have the same occlusion, because interpolation
    /// over a larger quad would otherwise smear the shading.
    private static func isFlat(_ key: UInt32) -> Bool {
        let first = (key >> 8) & 0b11
        return (key >> 10) & 0b11 == first && (key >> 12) & 0b11 == first && (key >> 14) & 0b11 == first
    }

    // MARK: - Quads

    private static func emitQuads(
        _ mask: inout [UInt32],
        builder: inout MeshBuilder,
        axis: Int,
        isPositive: Bool,
        layer: Int,
        width: Int,
        height: Int
    ) {
        let isGreedy = builder.options.strategy == .greedy

        for j in 0..<height {
            var i = 0
            while i < width {
                let key = mask[j * width + i]
                guard key != 0 else {
                    i += 1
                    continue
                }

                var quadWidth = 1
                var quadHeight = 1
                if isGreedy, isFlat(key) {
                    while i + quadWidth < width, mask[j * width + i + quadWidth] == key {
                        quadWidth += 1
                    }
                    rows: while j + quadHeight < height {
                        for offset in 0..<quadWidth where mask[(j + quadHeight) * width + i + offset] != key {
                            break rows
                        }
                        quadHeight += 1
                    }
                }

                for row in 0..<quadHeight {
                    for column in 0..<quadWidth {
                        mask[(j + row) * width + i + column] = 0
                    }
                }

                builder.appendQuad(
                    key: key,
                    axis: axis,
                    isPositive: isPositive,
                    plane: isPositive ? layer + 1 : layer,
                    origin: (i, j),
                    extent: (quadWidth, quadHeight)
                )
                i += quadWidth
            }
        }
    }
}

// MARK: - Mesh builder

private struct MeshBuilder {
    let options: VoxelMeshingOptions
    let palette: VOXPalette

    private var positions: [Vector3] = []
    private var normals: [Vector3] = []
    private var uvs: [Vector2] = []
    private var colors: [Color] = []
    private var indices: [UInt32] = []

    init(options: VoxelMeshingOptions, palette: VOXPalette) {
        self.options = options
        self.palette = palette
    }

    mutating func appendQuad(
        key: UInt32,
        axis: Int,
        isPositive: Bool,
        plane: Int,
        origin: (Int, Int),
        extent: (Int, Int)
    ) {
        let uAxis = (axis + 1) % 3
        let vAxis = (axis + 2) % 3

        // Corners in the order (-u,-v), (+u,-v), (+u,+v), (-u,+v); counter-clockwise seen from +axis.
        let corners = [
            (origin.0, origin.1),
            (origin.0 + extent.0, origin.1),
            (origin.0 + extent.0, origin.1 + extent.1),
            (origin.0, origin.1 + extent.1)
        ]
        let levels = (0..<4).map { Int((key >> UInt32(8 + $0 * 2)) & 0b11) }
        let order = isPositive ? [0, 1, 2, 3] : [0, 3, 2, 1]

        let sign: Float = isPositive ? 1 : -1
        let normal = switch axis {
        case 0: Vector3(sign, 0, 0)
        case 1: Vector3(0, sign, 0)
        default: Vector3(0, 0, sign)
        }

        let baseColor = palette.color(forIndex: UInt8(truncatingIfNeeded: key)) ?? VOXColor(red: 255, green: 0, blue: 255)
        let start = UInt32(positions.count)
        let uvCorners: [Vector2] = [[0, 0], [1, 0], [1, 1], [0, 1]]

        for (slot, corner) in order.enumerated() {
            var point = SIMD3<Int>(repeating: 0)
            point[axis] = plane
            point[uAxis] = corners[corner].0
            point[vAxis] = corners[corner].1
            positions.append(Vector3(Float(point.x), Float(point.y), Float(point.z)) * options.voxelSize)
            normals.append(normal)
            uvs.append(uvCorners[slot])

            let brightness = VoxelMesher.ambientOcclusionBrightness[levels[corner]]
            colors.append(
                Color(
                    red: Float(baseColor.red) / 255 * brightness,
                    green: Float(baseColor.green) / 255 * brightness,
                    blue: Float(baseColor.blue) / 255 * brightness,
                    alpha: Float(baseColor.alpha) / 255
                )
            )
        }

        // Split along the diagonal whose endpoints are darker to avoid anisotropic shading artifacts.
        let slotLevels = order.map { levels[$0] }
        if slotLevels[0] + slotLevels[2] <= slotLevels[1] + slotLevels[3] {
            indices += [start, start + 1, start + 2, start + 2, start + 3, start]
        } else {
            indices += [start + 1, start + 2, start + 3, start + 3, start, start + 1]
        }
    }

    func makeDescriptor(name: String) -> MeshDescriptor? {
        guard !indices.isEmpty else {
            return nil
        }
        var descriptor = MeshDescriptor(name: name)
        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.textureCoordinates = MeshBuffer(uvs)
        descriptor.colors = MeshBuffer(colors)
        descriptor.indicies = indices
        return descriptor
    }
}
