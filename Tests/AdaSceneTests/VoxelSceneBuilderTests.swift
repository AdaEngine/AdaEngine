import AdaAssets
import Math
import Testing
@_spi(Internal) import AdaRender
@testable import AdaScene

@Suite
struct VoxelSceneBuilderTests {
    private typealias Builder = VoxelSceneBuilder

    // MARK: - Fixtures

    private static func model(size: (Int, Int, Int), voxels: [(Int, Int, Int)], color: UInt8 = 1) -> VOXModel {
        VOXModel(
            sizeX: size.0,
            sizeY: size.1,
            sizeZ: size.2,
            voxels: voxels.map { VOXVoxel(x: UInt8($0.0), y: UInt8($0.1), z: UInt8($0.2), colorIndex: color) }
        )
    }

    private static func transform(
        id: Int,
        child: Int,
        name: String? = nil,
        hidden: Bool = false,
        frames: [VOXTransformFrame] = [VOXTransformFrame()]
    ) -> (Int, VOXNode) {
        (id, .transform(VOXTransformNode(id: id, name: name, isHidden: hidden, childID: child, frames: frames)))
    }

    private static func group(id: Int, children: [Int]) -> (Int, VOXNode) {
        (id, .group(VOXGroupNode(id: id, childIDs: children)))
    }

    private static func shape(id: Int, models: [Int]) -> (Int, VOXNode) {
        (id, .shape(VOXShapeNode(id: id, models: models.map { VOXShapeNode.ModelReference(modelIndex: $0) })))
    }

    private static func file(models: [VOXModel], nodes: [(Int, VOXNode)]) -> VOXFile {
        VOXFile(models: models, nodes: Dictionary(uniqueKeysWithValues: nodes))
    }

    private static func build(_ file: VOXFile, mergeStatic: Bool = false, maximumMergedVolume: Int = 1 << 26) -> VoxelSceneBuilder.Result {
        Builder.build(
            file: file,
            options: VoxelImportOptions(
                voxelSize: 1,
                mergeStatic: mergeStatic,
                meshingStrategy: .greedy,
                bakesAmbientOcclusion: false,
                maximumMergedVolume: maximumMergedVolume
            )
        )
    }

    private static func apply(_ matrix: Transform3D, to point: Vector3) -> Vector3 {
        Vector3(
            matrix.x.x * point.x + matrix.y.x * point.y + matrix.z.x * point.z + matrix.w.x,
            matrix.x.y * point.x + matrix.y.y * point.y + matrix.z.y * point.z + matrix.w.y,
            matrix.x.z * point.x + matrix.y.z * point.y + matrix.z.z * point.z + matrix.w.z
        )
    }

    /// Bounds of all geometry in engine space.
    private static func bounds(of result: VoxelSceneBuilder.Result) -> (min: Vector3, max: Vector3)? {
        var lower: Vector3?
        var upper: Vector3?

        func visit(_ index: Int, parent: Transform3D) {
            let node = result.nodes[index]
            let world = parent * node.transform
            if let meshIndex = node.meshIndex {
                for position in result.meshes[meshIndex].positions.elements {
                    let point = apply(world, to: position)
                    lower = lower.map { Vector3(min($0.x, point.x), min($0.y, point.y), min($0.z, point.z)) } ?? point
                    upper = upper.map { Vector3(max($0.x, point.x), max($0.y, point.y), max($0.z, point.z)) } ?? point
                }
            }
            for child in node.children {
                visit(child, parent: world)
            }
        }

        for child in result.nodes[result.rootNodeIndex].children {
            visit(child, parent: .identity)
        }
        guard let lower, let upper else {
            return nil
        }
        return (lower, upper)
    }

    private static func meshNodeCount(_ result: VoxelSceneBuilder.Result) -> Int {
        result.nodes.filter { $0.meshIndex != nil }.count
    }

    // MARK: - Tests

    @Test
    func convertsToLeftHandedYUpSpace() throws {
        let result = Self.build(
            Self.file(
                models: [Self.model(size: (2, 3, 4), voxels: [(1, 2, 3)])],
                nodes: [Self.transform(id: 0, child: 1), Self.shape(id: 1, models: [0])]
            )
        )

        // Pivot is (1, 1, 2); the cell box [0,1]x[1,2]x[1,2] in MagicaVoxel space swaps Y and Z.
        let bounds = try #require(Self.bounds(of: result))
        #expect(bounds.min == Vector3(0, 1, 1))
        #expect(bounds.max == Vector3(1, 2, 2))

        // Mirroring must not leave inside-out faces: winding follows the engine's own cube convention.
        let descriptor = try #require(result.meshes.first)
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
        // The top (+Z in MagicaVoxel) face now points up (+Y).
        #expect(normals.contains(Vector3(0, 1, 0)))
        #expect(!normals.contains { $0.z != 0 && $0.y != 0 })
    }

    @Test
    func centersModelsOnTheirPivot() throws {
        let result = Self.build(
            Self.file(
                models: [Self.model(size: (4, 2, 3), voxels: [(0, 0, 0), (3, 1, 2)])],
                nodes: [Self.transform(id: 0, child: 1), Self.shape(id: 1, models: [0])]
            )
        )

        let bounds = try #require(Self.bounds(of: result))
        // Pivot is floor(size / 2) = (2, 1, 1).
        // MagicaVoxel box [-2,2]x[-1,1]x[-1,2], with Y and Z swapped in engine space.
        #expect(bounds.min == Vector3(-2, -1, -1))
        #expect(bounds.max == Vector3(2, 2, 1))
    }

    @Test
    func appliesRotationAndTranslationAroundPivot() throws {
        let rotation = try #require(VOXRotation(packed: 17))
        #expect(rotation.apply(x: 1, y: 0, z: 0) == SIMD3(0, 1, 0))

        let frame = VOXTransformFrame(rotation: rotation, translation: SIMD3(5, 0, 0))
        let result = Self.build(
            Self.file(
                models: [Self.model(size: (2, 1, 1), voxels: [(0, 0, 0), (1, 0, 0)])],
                nodes: [Self.transform(id: 0, child: 1, frames: [frame]), Self.shape(id: 1, models: [0])]
            )
        )

        let bounds = try #require(Self.bounds(of: result))
        // Pivot-relative box [-1,1]x[0,1]x[0,1] rotates 90 degrees about Z to [-1,0]x[-1,1]x[0,1], then shifts by +5 in X.
        // In engine space Y and Z are swapped: [4,5]x[0,1]x[-1,1].
        #expect(bounds.min == Vector3(4, 0, -1))
        #expect(bounds.max == Vector3(5, 1, 1))
    }

    @Test
    func mergedMeshMatchesSeparateMeshBounds() throws {
        let rotation = try #require(VOXRotation(packed: 17))
        let nodes = [
            Self.transform(id: 0, child: 1),
            Self.group(id: 1, children: [2, 4]),
            Self.transform(id: 2, child: 3, frames: [VOXTransformFrame(rotation: rotation, translation: SIMD3(5, 2, 1))]),
            Self.shape(id: 3, models: [0]),
            Self.transform(id: 4, child: 5, frames: [VOXTransformFrame(translation: SIMD3(-3, 4, 0))]),
            Self.shape(id: 5, models: [1])
        ]
        let file = Self.file(
            models: [
                Self.model(size: (3, 2, 1), voxels: [(0, 0, 0), (2, 1, 0)]),
                Self.model(size: (1, 1, 2), voxels: [(0, 0, 0), (0, 0, 1)], color: 2)
            ],
            nodes: nodes
        )

        let separate = Self.build(file)
        let merged = Self.build(file, mergeStatic: true)

        #expect(Self.meshNodeCount(separate) == 2)
        #expect(Self.meshNodeCount(merged) == 1)
        let separateBounds = try #require(Self.bounds(of: separate))
        let mergedBounds = try #require(Self.bounds(of: merged))
        #expect(separateBounds.min == mergedBounds.min)
        #expect(separateBounds.max == mergedBounds.max)
    }

    @Test
    func mergingRemovesInnerFacesBetweenParts() throws {
        let nodes = [
            Self.transform(id: 0, child: 1),
            Self.group(id: 1, children: [2, 4]),
            Self.transform(id: 2, child: 3),
            Self.shape(id: 3, models: [0]),
            Self.transform(id: 4, child: 5, frames: [VOXTransformFrame(translation: SIMD3(1, 0, 0))]),
            Self.shape(id: 5, models: [0])
        ]
        let file = Self.file(models: [Self.model(size: (1, 1, 1), voxels: [(0, 0, 0)])], nodes: nodes)

        let separate = Self.build(file)
        let merged = Self.build(file, mergeStatic: true)

        #expect(separate.meshes.reduce(0) { $0 + $1.indicies.count / 6 } == 6)
        // The model mesh is shared between both instances.
        #expect(separate.meshes.count == 1)
        #expect(merged.meshes.count == 1)
        // Two touching same-color cubes become one 2x1x1 box.
        #expect(merged.meshes[0].indicies.count / 6 == 6)
    }

    @Test
    func keepsAnimatedSubtreesSeparateWhenMerging() throws {
        let animated = [VOXTransformFrame(translation: .zero, frameIndex: 0), VOXTransformFrame(translation: SIMD3(0, 0, 3), frameIndex: 10)]
        let nodes = [
            Self.transform(id: 0, child: 1),
            Self.group(id: 1, children: [2, 4, 6]),
            Self.transform(id: 2, child: 3, name: "arm", frames: animated),
            Self.shape(id: 3, models: [0]),
            Self.transform(id: 4, child: 5, name: "body", frames: [VOXTransformFrame(translation: SIMD3(4, 0, 0))]),
            Self.shape(id: 5, models: [0]),
            Self.transform(id: 6, child: 7, name: "head", frames: [VOXTransformFrame(translation: SIMD3(6, 0, 0))]),
            Self.shape(id: 7, models: [0])
        ]
        let file = Self.file(models: [Self.model(size: (1, 1, 1), voxels: [(0, 0, 0)])], nodes: nodes)

        let merged = Self.build(file, mergeStatic: true)

        // "arm" stays an addressable transform; the two static siblings merge into one mesh each (no shared root).
        #expect(merged.nodes.contains { $0.name == "arm" })
        #expect(!merged.nodes.contains { $0.name == "body" && $0.meshIndex == nil })
        #expect(merged.nodes.filter { $0.meshIndex != nil }.count == 3)
        // Without merging every part keeps its own transform.
        let separate = Self.build(file)
        #expect(separate.nodes.contains { $0.name == "body" })
        #expect(separate.nodes.contains { $0.name == "head" })
    }

    @Test
    func skipsHiddenNodesAndLayers() throws {
        let nodes = [
            Self.transform(id: 0, child: 1),
            Self.group(id: 1, children: [2, 4]),
            Self.transform(id: 2, child: 3, hidden: true),
            Self.shape(id: 3, models: [0]),
            (4, VOXNode.transform(VOXTransformNode(id: 4, childID: 5, layerID: 7))),
            Self.shape(id: 5, models: [0])
        ]
        var file = Self.file(models: [Self.model(size: (1, 1, 1), voxels: [(0, 0, 0)])], nodes: nodes)
        file.layers = [VOXLayer(id: 7, name: "Hidden", isHidden: true)]

        let result = Self.build(file)
        #expect(Self.meshNodeCount(result) == 0)
        #expect(Self.bounds(of: result) == nil)
    }

    @Test
    func placesModelsWhenFileHasNoSceneGraph() throws {
        let file = VOXFile(models: [Self.model(size: (2, 2, 2), voxels: [(0, 0, 0)])])
        let result = Self.build(file)

        let bounds = try #require(Self.bounds(of: result))
        #expect(bounds.min == Vector3(-1, -1, -1))
        #expect(bounds.max == Vector3(0, 0, 0))
    }

    @Test
    func fallsBackToSeparateMeshesWhenMergedVolumeIsTooLarge() throws {
        let nodes = [
            Self.transform(id: 0, child: 1),
            Self.group(id: 1, children: [2, 4]),
            Self.transform(id: 2, child: 3),
            Self.shape(id: 3, models: [0]),
            Self.transform(id: 4, child: 5, frames: [VOXTransformFrame(translation: SIMD3(100, 0, 0))]),
            Self.shape(id: 5, models: [0])
        ]
        let file = Self.file(models: [Self.model(size: (1, 1, 1), voxels: [(0, 0, 0)])], nodes: nodes)

        let result = Self.build(file, mergeStatic: true, maximumMergedVolume: 50)
        #expect(Self.meshNodeCount(result) == 2)
    }

    @Test
    func scalesTranslationsByVoxelSize() throws {
        let file = Self.file(
            models: [Self.model(size: (1, 1, 1), voxels: [(0, 0, 0)])],
            nodes: [
                Self.transform(id: 0, child: 1, frames: [VOXTransformFrame(translation: SIMD3(10, 0, 0))]),
                Self.shape(id: 1, models: [0])
            ]
        )
        let result = Builder.build(
            file: file,
            options: VoxelImportOptions(voxelSize: 0.1, bakesAmbientOcclusion: false)
        )

        let bounds = try #require(Self.bounds(of: result))
        #expect(abs(bounds.min.x - 1.0) < 0.0001)
        #expect(abs(bounds.max.x - 1.1) < 0.0001)
    }
}
