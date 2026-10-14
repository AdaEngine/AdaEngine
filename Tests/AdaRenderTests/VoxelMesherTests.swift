import AdaAssets
import AdaUtils
import Math
import Testing
@_spi(Internal) @testable import AdaRender

@Suite
struct VoxelMesherTests {
    private let palette = VOXPalette(
        colors: (0..<256).map { VOXColor(red: UInt8($0), green: 100, blue: 50, alpha: 255) }
    )

    private func grid(_ x: Int, _ y: Int, _ z: Int, solid: [(Int, Int, Int, UInt8)]) -> VoxelGrid {
        var grid = VoxelGrid(sizeX: x, sizeY: y, sizeZ: z)
        for voxel in solid {
            grid[voxel.0, voxel.1, voxel.2] = voxel.3
        }
        return grid
    }

    private func mesh(
        _ grid: VoxelGrid,
        strategy: VoxelMeshingOptions.Strategy = .greedy,
        ambientOcclusion: Bool = false,
        voxelSize: Float = 1
    ) -> MeshDescriptor? {
        VoxelMesher.makeDescriptor(
            grid: grid,
            palette: palette,
            options: VoxelMeshingOptions(voxelSize: voxelSize, strategy: strategy, bakesAmbientOcclusion: ambientOcclusion)
        )
    }

    private func quadCount(_ descriptor: MeshDescriptor?) -> Int {
        (descriptor?.indicies.count ?? 0) / 6
    }

    @Test
    func singleVoxelProducesSixFaces() throws {
        let descriptor = try #require(mesh(grid(1, 1, 1, solid: [(0, 0, 0, 1)])))

        #expect(quadCount(descriptor) == 6)
        #expect(descriptor.positions.count == 24)
        #expect(descriptor.indicies.count == 36)
    }

    @Test
    func emptyGridProducesNoMesh() {
        #expect(mesh(VoxelGrid(sizeX: 3, sizeY: 3, sizeZ: 3)) == nil)
        #expect(mesh(VoxelGrid(sizeX: 0, sizeY: 0, sizeZ: 0)) == nil)
    }

    @Test
    func trianglesWindCounterClockwiseAroundNormals() throws {
        let descriptor = try #require(
            mesh(grid(2, 2, 2, solid: [(0, 0, 0, 1), (1, 0, 0, 2), (0, 1, 0, 3), (0, 0, 1, 4)]), strategy: .culled, ambientOcclusion: true)
        )
        let positions = descriptor.positions.elements
        let normals = try #require(descriptor.normals).elements
        let indices = descriptor.indicies

        for triangle in stride(from: 0, to: indices.count, by: 3) {
            let a = positions[Int(indices[triangle])]
            let b = positions[Int(indices[triangle + 1])]
            let c = positions[Int(indices[triangle + 2])]
            let edge1 = (x: b.x - a.x, y: b.y - a.y, z: b.z - a.z)
            let edge2 = (x: c.x - a.x, y: c.y - a.y, z: c.z - a.z)
            let cross = (
                x: edge1.y * edge2.z - edge1.z * edge2.y,
                y: edge1.z * edge2.x - edge1.x * edge2.z,
                z: edge1.x * edge2.y - edge1.y * edge2.x
            )
            let normal = normals[Int(indices[triangle])]
            #expect(cross.x * normal.x + cross.y * normal.y + cross.z * normal.z > 0)
        }
    }

    @Test
    func adjacentVoxelsHideSharedFaces() throws {
        let descriptor = mesh(grid(2, 1, 1, solid: [(0, 0, 0, 1), (1, 0, 0, 2)]), strategy: .culled)
        // 12 faces minus the two touching ones.
        #expect(quadCount(descriptor) == 10)
    }

    @Test
    func greedyMergesFlatSameColorFaces() {
        let plate = grid(4, 4, 1, solid: (0..<4).flatMap { y in (0..<4).map { x in (x, y, 0, UInt8(1)) } })

        #expect(quadCount(mesh(plate, strategy: .culled)) == 48)
        // Top and bottom merge into one quad each, every side into one 4x1 quad.
        #expect(quadCount(mesh(plate, strategy: .greedy)) == 6)
    }

    @Test
    func greedyDoesNotMergeDifferentColors() {
        let row = grid(2, 1, 1, solid: [(0, 0, 0, 1), (1, 0, 0, 2)])
        #expect(quadCount(mesh(row, strategy: .greedy)) == 10)
    }

    @Test
    func greedyMatchesCulledSurfaceArea() throws {
        let solid = (0..<3).flatMap { z in (0..<3).flatMap { y in (0..<3).map { x in (x, y, z, UInt8(1 + (x + y + z) % 2)) } } }
        let shape = grid(3, 3, 3, solid: solid.filter { $0.0 != 1 || $0.1 != 1 })

        func area(_ descriptor: MeshDescriptor) -> Float {
            let positions = descriptor.positions.elements
            return stride(from: 0, to: descriptor.indicies.count, by: 3).reduce(0) { total, triangle in
                let a = positions[Int(descriptor.indicies[triangle])]
                let b = positions[Int(descriptor.indicies[triangle + 1])]
                let c = positions[Int(descriptor.indicies[triangle + 2])]
                let edge1 = (x: b.x - a.x, y: b.y - a.y, z: b.z - a.z)
                let edge2 = (x: c.x - a.x, y: c.y - a.y, z: c.z - a.z)
                let x = edge1.y * edge2.z - edge1.z * edge2.y
                let y = edge1.z * edge2.x - edge1.x * edge2.z
                let z = edge1.x * edge2.y - edge1.y * edge2.x
                return total + (x * x + y * y + z * z).squareRoot() / 2
            }
        }

        let culled = try #require(mesh(shape, strategy: .culled))
        let greedy = try #require(mesh(shape, strategy: .greedy))
        #expect(abs(area(culled) - area(greedy)) < 0.001)
        #expect(quadCount(greedy) <= quadCount(culled))
    }

    @Test
    func bakesAmbientOcclusionNextToWalls() throws {
        let floorAndPillar = grid(
            3,
            3,
            2,
            solid: (0..<3).flatMap { y in (0..<3).map { x in (x, y, 0, UInt8(10)) } } + [(1, 1, 1, UInt8(10))]
        )

        let flat = try #require(mesh(floorAndPillar, ambientOcclusion: false))
        let occluded = try #require(mesh(floorAndPillar, ambientOcclusion: true))

        let flatReds = try #require(flat.colors).elements.map(\.red)
        let occludedReds = try #require(occluded.colors).elements.map(\.red)
        #expect(Set(flatReds).count == 1)
        #expect(occludedReds.min() ?? 1 < flatReds.min() ?? 0)
        // Occlusion never brightens a vertex.
        #expect(occludedReds.max() ?? 0 <= flatReds.max() ?? 0)
    }

    @Test
    func mapsPaletteIndicesToVertexColors() throws {
        let descriptor = try #require(mesh(grid(1, 1, 1, solid: [(0, 0, 0, 3)])))
        let colors = try #require(descriptor.colors).elements

        // Palette index 3 maps to colors[2], whose red channel is 2.
        #expect(colors.allSatisfy { abs($0.red - 2.0 / 255) < 0.0001 })
        #expect(colors.allSatisfy { $0.alpha == 1 })
    }

    @Test
    func scalesByVoxelSize() throws {
        let descriptor = try #require(mesh(grid(2, 1, 1, solid: [(0, 0, 0, 1), (1, 0, 0, 1)]), voxelSize: 0.1))
        let positions = descriptor.positions.elements

        #expect(abs((positions.map(\.x).max() ?? 0) - 0.2) < 0.0001)
        #expect(abs((positions.map(\.y).max() ?? 0) - 0.1) < 0.0001)
    }

    @Test
    func buildsGridFromVOXModel() {
        let model = VOXModel(
            sizeX: 2,
            sizeY: 2,
            sizeZ: 2,
            voxels: [VOXVoxel(x: 1, y: 0, z: 1, colorIndex: 7)]
        )
        let grid = VoxelGrid(model: model)

        #expect(grid.solidCount == 1)
        #expect(grid[1, 0, 1] == 7)
        #expect(grid[0, 0, 0] == 0)
        #expect(grid[5, 5, 5] == 0)
    }
}
