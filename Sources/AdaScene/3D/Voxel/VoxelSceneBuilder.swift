//
//  VoxelSceneBuilder.swift
//  AdaEngine
//

import AdaAssets
@_spi(Internal) import AdaRender
import Math

/// Converts a parsed MagicaVoxel scene to engine nodes and mesh descriptors without touching the GPU.
///
/// Coordinate conventions: MagicaVoxel is right-handed with Z up; the engine is left-handed with Y up and +Z forward.
/// The scene is built in MagicaVoxel space and then converted by swapping the Y and Z axes
/// (`(x, y, z) -> (x, z, y)`), which keeps the model's look from MagicaVoxel's default front view (it faces +Z,
/// +X is right, +Z becomes up). The swap is a mirror, so it is baked into mesh vertices (with reversed triangle
/// winding) and applied to node matrices by conjugation instead of being left as a negative-determinant node transform.
/// A model's pivot is `floor(size / 2)`, as in the MagicaVoxel scene graph.
struct VoxelSceneBuilder {
    struct Node {
        var name: String?
        var transform: Transform3D
        var meshIndex: Int?
        var children: [Int]
        var animation: VoxelNodeAnimation?

        init(name: String?, transform: Transform3D, meshIndex: Int?, children: [Int], animation: VoxelNodeAnimation? = nil) {
            self.name = name
            self.transform = transform
            self.meshIndex = meshIndex
            self.children = children
            self.animation = animation
        }
    }

    struct Result {
        var nodes: [Node]
        var meshes: [MeshDescriptor]
        var rootNodeIndex: Int
    }

    /// Rotation by a signed axis permutation plus an integer translation in voxel units.
    struct VoxelTransform: Equatable {
        var rows: [SIMD3<Int>]
        var translation: SIMD3<Int>

        static let identity = VoxelTransform(
            rows: [SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1)],
            translation: .zero
        )

        init(rows: [SIMD3<Int>], translation: SIMD3<Int>) {
            self.rows = rows
            self.translation = translation
        }

        init(frame: VOXTransformFrame) {
            let rotation = frame.rotation
            self.init(
                rows: [rotation.row0, rotation.row1, rotation.row2].map { SIMD3(Int($0.x), Int($0.y), Int($0.z)) },
                translation: frame.translation
            )
        }

        func rotate(_ vector: SIMD3<Int>) -> SIMD3<Int> {
            SIMD3(
                (rows[0] &* vector).wrappedSum(),
                (rows[1] &* vector).wrappedSum(),
                (rows[2] &* vector).wrappedSum()
            )
        }

        /// Returns the transform applying `child` first and `self` second.
        func composed(with child: VoxelTransform) -> VoxelTransform {
            let composedRows = rows.map { row in
                row.x &* child.rows[0] &+ row.y &* child.rows[1] &+ row.z &* child.rows[2]
            }
            return VoxelTransform(rows: composedRows, translation: rotate(child.translation) &+ translation)
        }

        /// Maps a cell index relative to the model pivot to a cell index in the parent frame.
        func mapCell(_ cell: SIMD3<Int>) -> SIMD3<Int> {
            // Work with doubled cell centers so rotation of half-integer centers stays exact.
            let center = rotate(cell &* 2 &+ 1) &+ translation &* 2
            return (center &- 1) / 2
        }

        var matrix: Transform3D {
            Transform3D(
                Vector4(Float(rows[0].x), Float(rows[1].x), Float(rows[2].x), 0),
                Vector4(Float(rows[0].y), Float(rows[1].y), Float(rows[2].y), 0),
                Vector4(Float(rows[0].z), Float(rows[1].z), Float(rows[2].z), 0),
                Vector4(0, 0, 0, 1)
            )
        }
    }

    /// Swaps the Y and Z axes. Its own inverse.
    static let axisSwap = Transform3D(
        Vector4(1, 0, 0, 0),
        Vector4(0, 0, 1, 0),
        Vector4(0, 1, 0, 0),
        Vector4(0, 0, 0, 1)
    )

    private let file: VOXFile
    private let options: VoxelImportOptions
    private var nodes: [Node] = []
    private var meshes: [MeshDescriptor] = []
    private var meshIndexByModel: [Int: Int] = [:]

    static func build(file: VOXFile, options: VoxelImportOptions) -> Result {
        var builder = VoxelSceneBuilder(file: file, options: options)
        return builder.build()
    }

    private init(file: VOXFile, options: VoxelImportOptions) {
        self.file = file
        self.options = options
    }

    private mutating func build() -> Result {
        let wrapper = reserveNode()
        let contentIndex: Int?
        if let root = file.rootNode {
            contentIndex = emit(root.id, allowsMerging: true)
        } else {
            contentIndex = emitUnparentedModels()
        }

        nodes[wrapper] = Node(
            name: "Voxels",
            transform: .identity,
            meshIndex: nil,
            children: contentIndex.map { [$0] } ?? []
        )
        return Result(
            nodes: nodes.map { node in
                var converted = node
                converted.transform = Self.axisSwap * node.transform * Self.axisSwap
                return converted
            },
            meshes: meshes.map(Self.convertedToEngineSpace),
            rootNodeIndex: wrapper
        )
    }

    /// Swaps Y and Z in positions and normals and reverses the triangle winding to compensate for the mirror.
    private static func convertedToEngineSpace(_ descriptor: MeshDescriptor) -> MeshDescriptor {
        var converted = descriptor
        converted.positions = MeshBuffer(descriptor.positions.elements.map { Vector3($0.x, $0.z, $0.y) })
        converted.normals = descriptor.normals.map { buffer in
            MeshBuffer(buffer.elements.map { Vector3($0.x, $0.z, $0.y) })
        }
        var indices = descriptor.indicies
        for triangle in stride(from: 0, to: indices.count - 2, by: 3) {
            indices.swapAt(triangle + 1, triangle + 2)
        }
        converted.indicies = indices
        return converted
    }

    // MARK: - Hierarchy

    private mutating func reserveNode() -> Int {
        nodes.append(Node(name: nil, transform: .identity, meshIndex: nil, children: []))
        return nodes.count - 1
    }

    private mutating func emit(_ id: Int, allowsMerging: Bool) -> Int? {
        guard let node = file.nodes[id] else {
            return nil
        }

        switch node {
        case .transform(let transform):
            guard isVisible(transform) else {
                return nil
            }
            if allowsMerging, options.mergeStatic, isStatic(id), containsShape(id) {
                if let merged = emitMerged(transform) {
                    return merged
                }
                if exceedsMergeLimit(transform) {
                    return emit(id, allowsMerging: false)
                }
                return nil
            }
            let index = reserveNode()
            let frame = transform.frames.first.map(VoxelTransform.init(frame:)) ?? .identity
            var matrix = frame.matrix
            matrix.w = Vector4(
                Float(frame.translation.x) * options.voxelSize,
                Float(frame.translation.y) * options.voxelSize,
                Float(frame.translation.z) * options.voxelSize,
                1
            )
            let child = emit(transform.childID, allowsMerging: allowsMerging)
            nodes[index] = Node(
                name: transform.name,
                transform: matrix,
                meshIndex: nil,
                children: child.map { [$0] } ?? [],
                animation: transform.isAnimated ? transformAnimation(for: transform) : nil
            )
            return index
        case .group(let group):
            let index = reserveNode()
            let children = group.childIDs.compactMap { emit($0, allowsMerging: allowsMerging) }
            nodes[index] = Node(name: nil, transform: .identity, meshIndex: nil, children: children)
            return index
        case .shape(let shape):
            return shape.models.first.flatMap { emitShape(modelIndex: $0.modelIndex, shape: shape) }
        }
    }

    /// Files without a scene graph place every model on its own pivot.
    private mutating func emitUnparentedModels() -> Int? {
        let index = reserveNode()
        let children = file.models.indices.compactMap { emitShape(modelIndex: $0) }
        nodes[index] = Node(name: nil, transform: .identity, meshIndex: nil, children: children)
        return index
    }

    private mutating func emitShape(modelIndex: Int, shape: VOXShapeNode? = nil) -> Int? {
        guard file.models.indices.contains(modelIndex), let mesh = meshIndex(forModel: modelIndex) else {
            return nil
        }
        let model = file.models[modelIndex]
        let pivot = Self.pivot(of: model)
        let index = reserveNode()
        nodes[index] = Node(
            name: nil,
            transform: Transform3D(translation: Vector3(Float(-pivot.x), Float(-pivot.y), Float(-pivot.z)) * options.voxelSize),
            meshIndex: mesh,
            children: [],
            animation: shape?.isAnimated == true ? shapeAnimation(for: shape) : nil
        )
        return index
    }

    /// Keys for an `nTRN` with several frames, in engine space.
    private func transformAnimation(for transform: VOXTransformNode) -> VoxelNodeAnimation {
        let keys = transform.frames.enumerated().map { index, frame in
            var matrix = VoxelTransform(frame: frame).matrix
            matrix.w = Vector4(
                Float(frame.translation.x) * options.voxelSize,
                Float(frame.translation.y) * options.voxelSize,
                Float(frame.translation.z) * options.voxelSize,
                1
            )
            return VoxelNodeAnimation.TransformKey(
                frame: frame.frameIndex ?? index,
                transform: Transform(matrix: Self.axisSwap * matrix * Self.axisSwap)
            )
        }
        return VoxelNodeAnimation(transformKeys: keys)
    }

    /// Keys for an `nSHP` that switches between models. Every model brings its own pivot offset.
    private mutating func shapeAnimation(for shape: VOXShapeNode?) -> VoxelNodeAnimation? {
        guard let shape else {
            return nil
        }
        var keys: [VoxelNodeAnimation.ShapeKey] = []
        for (index, reference) in shape.models.enumerated() {
            guard file.models.indices.contains(reference.modelIndex), let mesh = meshIndex(forModel: reference.modelIndex) else {
                continue
            }
            let pivot = Self.pivot(of: file.models[reference.modelIndex])
            // Offsets are expressed in engine space, so Y and Z swap.
            let offset = Vector3(Float(-pivot.x), Float(-pivot.z), Float(-pivot.y)) * options.voxelSize
            keys.append(.init(frame: reference.frameIndex ?? index, meshIndex: mesh, offset: offset))
        }
        return keys.isEmpty ? nil : VoxelNodeAnimation(shapeKeys: keys)
    }

    private mutating func meshIndex(forModel modelIndex: Int) -> Int? {
        if let cached = meshIndexByModel[modelIndex] {
            return cached
        }
        let grid = VoxelGrid(model: file.models[modelIndex])
        guard let descriptor = VoxelMesher.makeDescriptor(
            grid: grid,
            palette: file.palette,
            options: options.meshingOptions,
            name: "VoxelModel \(modelIndex)"
        ) else {
            return nil
        }
        meshes.append(descriptor)
        meshIndexByModel[modelIndex] = meshes.count - 1
        return meshes.count - 1
    }

    // MARK: - Visibility and static analysis

    private func isVisible(_ transform: VOXTransformNode) -> Bool {
        guard !transform.isHidden else {
            return false
        }
        return file.layers.first { $0.id == transform.layerID }?.isHidden != true
    }

    private func isStatic(_ id: Int) -> Bool {
        switch file.nodes[id] {
        case .transform(let transform):
            !transform.isAnimated && isStatic(transform.childID)
        case .group(let group):
            group.childIDs.allSatisfy { isStatic($0) }
        case .shape(let shape):
            !shape.isAnimated
        case nil:
            true
        }
    }

    private func containsShape(_ id: Int) -> Bool {
        switch file.nodes[id] {
        case .transform(let transform):
            containsShape(transform.childID)
        case .group(let group):
            group.childIDs.contains { containsShape($0) }
        case .shape(let shape):
            !shape.models.isEmpty
        case nil:
            false
        }
    }

    // MARK: - Merging

    private static func pivot(of model: VOXModel) -> SIMD3<Int> {
        SIMD3(model.sizeX / 2, model.sizeY / 2, model.sizeZ / 2)
    }

    private func collectShapes(_ id: Int, transform: VoxelTransform, into shapes: inout [(model: Int, transform: VoxelTransform)]) {
        switch file.nodes[id] {
        case .transform(let node):
            guard isVisible(node) else {
                return
            }
            let frame = node.frames.first.map(VoxelTransform.init(frame:)) ?? .identity
            collectShapes(node.childID, transform: transform.composed(with: frame), into: &shapes)
        case .group(let group):
            for child in group.childIDs {
                collectShapes(child, transform: transform, into: &shapes)
            }
        case .shape(let shape):
            if let model = shape.models.first, file.models.indices.contains(model.modelIndex) {
                shapes.append((model.modelIndex, transform))
            }
        case nil:
            break
        }
    }

    /// Cell bounds of every shape in the merged (parent) frame.
    private func mergedBounds(of shapes: [(model: Int, transform: VoxelTransform)]) -> (min: SIMD3<Int>, max: SIMD3<Int>)? {
        var lower: SIMD3<Int>?
        var upper: SIMD3<Int>?
        for shape in shapes {
            let model = file.models[shape.model]
            let pivot = Self.pivot(of: model)
            let low = SIMD3<Int>(0, 0, 0) &- pivot
            let high = SIMD3(model.sizeX - 1, model.sizeY - 1, model.sizeZ - 1) &- pivot
            for corner in 0..<8 {
                let cell = SIMD3(
                    corner & 1 == 0 ? low.x : high.x,
                    corner & 2 == 0 ? low.y : high.y,
                    corner & 4 == 0 ? low.z : high.z
                )
                let mapped = shape.transform.mapCell(cell)
                lower = lower.map { pointwiseMin($0, mapped) } ?? mapped
                upper = upper.map { pointwiseMax($0, mapped) } ?? mapped
            }
        }
        guard let lower, let upper else {
            return nil
        }
        return (lower, upper)
    }

    private func mergedShapes(for transform: VOXTransformNode) -> [(model: Int, transform: VoxelTransform)] {
        var shapes: [(model: Int, transform: VoxelTransform)] = []
        collectShapes(transform.id, transform: .identity, into: &shapes)
        return shapes
    }

    private func exceedsMergeLimit(_ transform: VOXTransformNode) -> Bool {
        guard let bounds = mergedBounds(of: mergedShapes(for: transform)) else {
            return false
        }
        let size = bounds.max &- bounds.min &+ 1
        return size.x * size.y * size.z > options.maximumMergedVolume
    }

    /// Merges every shape below `transform` into one mesh placed in the parent frame of the transform node.
    private mutating func emitMerged(_ transform: VOXTransformNode) -> Int? {
        let shapes = mergedShapes(for: transform)
        guard let bounds = mergedBounds(of: shapes) else {
            return nil
        }
        let size = bounds.max &- bounds.min &+ 1
        guard size.x * size.y * size.z <= options.maximumMergedVolume else {
            return nil
        }

        var grid = VoxelGrid(sizeX: size.x, sizeY: size.y, sizeZ: size.z)
        for shape in shapes {
            let model = file.models[shape.model]
            let pivot = Self.pivot(of: model)
            for voxel in model.voxels {
                let cell = shape.transform.mapCell(SIMD3(Int(voxel.x), Int(voxel.y), Int(voxel.z)) &- pivot) &- bounds.min
                grid[cell.x, cell.y, cell.z] = voxel.colorIndex
            }
        }

        guard let descriptor = VoxelMesher.makeDescriptor(
            grid: grid,
            palette: file.palette,
            options: options.meshingOptions,
            name: transform.name ?? "VoxelMerged"
        ) else {
            return nil
        }
        meshes.append(descriptor)

        let index = reserveNode()
        nodes[index] = Node(
            name: transform.name,
            transform: Transform3D(
                translation: Vector3(Float(bounds.min.x), Float(bounds.min.y), Float(bounds.min.z)) * options.voxelSize
            ),
            meshIndex: meshes.count - 1,
            children: []
        )
        return index
    }
}

private extension SIMD3 where Scalar == Int {
    func wrappedSum() -> Int {
        x &+ y &+ z
    }
}
