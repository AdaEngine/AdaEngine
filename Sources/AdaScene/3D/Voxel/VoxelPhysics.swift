//
//  VoxelPhysics.swift
//  AdaEngine
//

import AdaAssets
import AdaECS
import AdaPhysics
@_spi(Internal) import AdaRender
import AdaTransform
import Math

/// An axis-aligned box of voxels, in cells.
public struct VoxelBox: Hashable, Sendable {
    /// Minimum cell of the box.
    public var origin: SIMD3<Int>
    /// Extent in cells, at least 1 on every axis.
    public var size: SIMD3<Int>

    public init(origin: SIMD3<Int>, size: SIMD3<Int>) {
        self.origin = origin
        self.size = size
    }

    public var volume: Int {
        size.x * size.y * size.z
    }
}

/// Merges solid voxels into a small set of boxes for physics colliders.
public enum VoxelColliderBuilder {
    /// Greedily merges solid cells of `region` (the whole grid by default) into boxes.
    ///
    /// Cells are merged along X first, then Y, then Z. Box origins are relative to the region's minimum corner. Every
    /// solid cell belongs to exactly one box, so the union of the boxes equals the solid volume.
    public static func boxes(in grid: VoxelGrid, region: VoxelMeshingRegion? = nil) -> [VoxelBox] {
        let region = region ?? VoxelMeshingRegion(origin: .zero, size: SIMD3(grid.sizeX, grid.sizeY, grid.sizeZ))
        let size = region.size
        guard size.x > 0, size.y > 0, size.z > 0 else {
            return []
        }

        var taken = [Bool](repeating: false, count: size.x * size.y * size.z)
        func index(_ x: Int, _ y: Int, _ z: Int) -> Int {
            (z * size.y + y) * size.x + x
        }
        func isFree(_ x: Int, _ y: Int, _ z: Int) -> Bool {
            !taken[index(x, y, z)] && grid[region.origin.x + x, region.origin.y + y, region.origin.z + z] != 0
        }

        var boxes: [VoxelBox] = []
        for z in 0..<size.z {
            for y in 0..<size.y {
                for x in 0..<size.x where isFree(x, y, z) {
                    var width = 1
                    while x + width < size.x, isFree(x + width, y, z) {
                        width += 1
                    }

                    var height = 1
                    heightLoop: while y + height < size.y {
                        for dx in 0..<width where !isFree(x + dx, y + height, z) {
                            break heightLoop
                        }
                        height += 1
                    }

                    var depth = 1
                    depthLoop: while z + depth < size.z {
                        for dy in 0..<height {
                            for dx in 0..<width where !isFree(x + dx, y + dy, z + depth) {
                                break depthLoop
                            }
                        }
                        depth += 1
                    }

                    for dz in 0..<depth {
                        for dy in 0..<height {
                            for dx in 0..<width {
                                taken[index(x + dx, y + dy, z + dz)] = true
                            }
                        }
                    }
                    boxes.append(VoxelBox(origin: SIMD3(x, y, z), size: SIMD3(width, height, depth)))
                }
            }
        }
        return boxes
    }

    /// Box shapes for physics, scaled by `voxelSize`. `offset` (in cells) is subtracted from box origins so shapes can be
    /// expressed around a body origin other than the grid's minimum corner.
    public static func shapes(for boxes: [VoxelBox], voxelSize: Float, offset: Vector3 = .zero) -> [Shape3DResource] {
        boxes.map { box in
            let center = (Vector3(Float(box.origin.x), Float(box.origin.y), Float(box.origin.z)) + Vector3(Float(box.size.x), Float(box.size.y), Float(box.size.z)) * 0.5 - offset)
                * voxelSize
            return Shape3DResource.generateBox(
                width: Float(box.size.x) * voxelSize,
                height: Float(box.size.y) * voxelSize,
                depth: Float(box.size.z) * voxelSize,
                center: center
            )
        }
    }
}

/// A group of voxels that was cut off from the world, ready to become a dynamic body.
public struct VoxelIsland: Sendable {
    /// World voxel coordinate of the grid's minimum cell.
    public let origin: SIMD3<Int>
    public let grid: VoxelGrid
    public let voxelCount: Int

    public init(origin: SIMD3<Int>, grid: VoxelGrid, voxelCount: Int) {
        self.origin = origin
        self.grid = grid
        self.voxelCount = voxelCount
    }

    /// Spawns a dynamic physics body with a mesh and box colliders for this island.
    ///
    /// The body sits at the island's center in the space of `worldTransform` (the voxel world's transform). The mesh
    /// lives on a child entity so the body origin can stay at the center.
    ///
    /// - Parameters:
    ///   - density: Mass in kilograms per cubic world unit.
    /// - Returns: The body entity, or `nil` when the island has no exposed faces.
    @discardableResult
    @MainActor
    public func spawnBody(
        in world: World,
        palette: VOXPalette,
        voxelSize: Float,
        worldTransform: Transform3D = .identity,
        density: Float = 800,
        meshingStrategy: VoxelMeshingOptions.Strategy = .greedy
    ) -> Entity? {
        let options = VoxelMeshingOptions(voxelSize: voxelSize, strategy: meshingStrategy, bakesAmbientOcclusion: true)
        guard let descriptor = VoxelMesher.makeDescriptor(grid: grid, palette: palette, options: options, name: "VoxelIsland") else {
            return nil
        }

        let half = Vector3(Float(grid.sizeX), Float(grid.sizeY), Float(grid.sizeZ)) * 0.5
        let boxes = VoxelColliderBuilder.boxes(in: grid)
        let shapes = VoxelColliderBuilder.shapes(for: boxes, voxelSize: voxelSize, offset: half)

        let device = unsafe RenderEngine.shared.renderDevice
        let material = PBRMaterial()
        material.metallicFactor = 0
        material.roughnessFactor = 0.85

        let centerInWorld = (Vector3(Float(origin.x), Float(origin.y), Float(origin.z)) + half) * voxelSize
        let position = (worldTransform * Vector4(centerInWorld, 1)).xyz
        let mass = Float(voxelCount) * voxelSize * voxelSize * voxelSize * density

        let body = world.spawn("VoxelIsland")
        body.components[Transform.self] = Transform(rotation: Transform(matrix: worldTransform).rotation, scale: .one, position: position)
        // The material density makes the mass computed from the box volumes equal to `mass`. Overriding only the mass would
        // leave the inertia of a much lighter body, and heavy blocks then tunnel through thin colliders.
        body.components[PhysicsBody3DComponent.self] = PhysicsBody3DComponent(
            shapes: shapes,
            mass: mass,
            material: .generate(friction: 0.6, restitution: 0, density: density),
            mode: .dynamic
        )

        let visual = world.spawn("VoxelIslandMesh")
        visual.components[Transform.self] = Transform(position: -half * voxelSize)
        visual.components[Mesh3DComponent.self] = Mesh3DComponent(
            mesh: Mesh.generate(from: [descriptor], renderDevice: device),
            materials: [material]
        )
        body.addChild(visual)
        return body
    }
}
