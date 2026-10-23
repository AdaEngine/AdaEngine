import Math
import Testing

@testable import AdaAssets

@Suite("Procedural models")
struct ProceduralModelTests {
    private static let solids: [(String, ProceduralMeshData)] = [
        ("box", ProceduralGeometry.box(width: 2, height: 1, depth: 3)),
        ("sphere", ProceduralGeometry.sphere(radius: 1, segments: 16)),
        ("cylinder", ProceduralGeometry.cylinder(radiusTop: 1, radiusBottom: 1, height: 2, segments: 12)),
        ("cone", ProceduralGeometry.cylinder(radiusTop: 0, radiusBottom: 1, height: 2, segments: 12)),
        ("capsule", ProceduralGeometry.capsule(radius: 0.5, height: 2, segments: 12)),
    ]

    @Test("Convex solids wind every triangle outward and carry unit normals", arguments: solids)
    func windingIsOutward(name: String, mesh: ProceduralMeshData) {
        #expect(!mesh.isEmpty, "\(name)")
        #expect(mesh.positions.count == mesh.normals.count && mesh.positions.count == mesh.uvs.count)
        #expect(mesh.normals.allSatisfy { abs(vecLength($0) - 1) < 1e-4 }, "\(name)")
        for start in stride(from: 0, to: mesh.indices.count, by: 3) {
            let corners = (0..<3).map { Int(mesh.indices[start + $0]) }
            let (a, b, c) = (mesh.positions[corners[0]], mesh.positions[corners[1]], mesh.positions[corners[2]])
            let face = vecCross(b - a, c - a)
            #expect(vecLength(face) > 1e-9, "\(name) has a degenerate triangle")
            // The solids are convex around the origin, so a triangle's centroid points the same way as its outward face.
            #expect((face * (a + b + c)).sum() > 0, "\(name) triangle \(start / 3) faces inward")
            let shading = corners.map { mesh.normals[$0] }.reduce(SIMD3<Float>.zero, +)
            #expect((face * shading).sum() > 0, "\(name) normal disagrees with winding")
        }
    }

    @Test("Torus and lathe profiles keep normals consistent with winding")
    func torusWinding() {
        let mesh = ProceduralGeometry.torus(majorRadius: 1, minorRadius: 0.25, segments: 16)
        #expect(!mesh.isEmpty)
        for start in stride(from: 0, to: mesh.indices.count, by: 3) {
            let corners = (0..<3).map { Int(mesh.indices[start + $0]) }
            let face = vecCross(mesh.positions[corners[1]] - mesh.positions[corners[0]], mesh.positions[corners[2]] - mesh.positions[corners[0]])
            let shading = corners.map { mesh.normals[$0] }.reduce(SIMD3<Float>.zero, +)
            #expect((face * shading).sum() > 0)
        }
        #expect(ProceduralGeometry.lathe(profile: [[1, 0]], segments: 8).isEmpty)
        #expect(ProceduralGeometry.lathe(profile: [[0, 1], [1, 0]], segments: 2).isEmpty)
    }

    @Test("Smooth normals stay shared on a sphere and split at a cylinder's cap edge")
    func creases() {
        let sphere = ProceduralGeometry.sphere(radius: 1, segments: 32)
        for (position, normal) in zip(sphere.positions, sphere.normals) where vecLength(position) > 0.5 {
            #expect(vecDot2(vecNormalize(position), normal) > 0.98)
        }
        let cylinder = ProceduralGeometry.cylinder(radiusTop: 1, radiusBottom: 1, height: 2, segments: 12)
        #expect(cylinder.normals.contains { abs($0.y - 1) < 1e-4 })
        #expect(cylinder.normals.contains { abs($0.y) < 1e-4 && abs(vecLength($0) - 1) < 1e-4 })
    }

    @Test("Flat meshes skip degenerate triangles and shade each face")
    func flatMesh() {
        let mesh = ProceduralGeometry.flat(vertices: [[0, 0, 0], [1, 0, 0], [0, 1, 0], [2, 0, 0]], triangles: [[0, 1, 2], [0, 1, 3]])
        #expect(mesh.positions.count == 3)
        #expect(mesh.normals.allSatisfy { $0 == SIMD3<Float>(0, 0, 1) })
    }

    @Test("Euler angles compose roll, pitch, then yaw")
    func quaternions() {
        #expect(ProceduralMath.quaternion(eulerDegrees: .zero) == SIMD4(0, 0, 0, 1))
        let yaw = ProceduralMath.quaternion(eulerDegrees: [0, 90, 0])
        #expect(abs(yaw.y - 0.70710677) < 1e-5 && abs(yaw.w - 0.70710677) < 1e-5)
        let combined = ProceduralMath.quaternion(eulerDegrees: [30, 45, 60])
        #expect(abs((combined * combined).sum() - 1) < 1e-5)
    }

    @Test("GLB output imports with hierarchy, materials and geometry")
    func glbRoundTrip() throws {
        var root = ProceduralNode(name: "Root")
        root.translation = [1, 2, 3]
        var body = ProceduralNode(name: "Body", mesh: ProceduralGeometry.box(width: 1, height: 1, depth: 1))
        body.parent = 0
        body.material = 1
        body.rotation = ProceduralMath.quaternion(eulerDegrees: [0, 90, 0])
        body.scale = [2, 1, 1]
        let model = ProceduralModel(
            materials: [
                ProceduralMaterial(name: "Default"),
                ProceduralMaterial(name: "Gold", baseColor: [1, 0.8, 0.1, 1], metallic: 1, roughness: 0.3, emissive: [0.1, 0, 0]),
            ],
            nodes: [root, body]
        )
        let data = try GLBWriter().encode(model)
        #expect(data.count % 4 == 0)

        let result = try NativeGLTFLoader().load(data: data)
        #expect(result.nodes.map(\.name) == ["Root", "Body"])
        #expect(result.nodes[0].children == [1])
        #expect(result.nodes[0].meshIndex == nil)
        #expect(result.scenes == [[0]])
        let meshIndex = try #require(result.nodes[1].meshIndex)
        let primitive = try #require(result.meshes[meshIndex].primitives.first)
        #expect(primitive.attributes[.position]?.count == 24)
        #expect(primitive.attributes[.normal]?.count == 24)
        #expect(primitive.attributes[.texCoord(0)]?.count == 24)
        #expect(primitive.indices?.count == 36)
        #expect(primitive.materialIndex == 1)
        let gold = result.materials[1]
        #expect(gold.name == "Gold")
        #expect(gold.metallicFactor == 1 && gold.roughnessFactor == 0.3)
        #expect(gold.emissiveFactor.x == 0.1)
    }

    @Test("Scale of a part without children is baked into its geometry so normals stay correct")
    func bakesLeafScale() throws {
        var group = ProceduralNode(name: "Group")
        group.scale = [2, 2, 2]
        var cloud = ProceduralNode(name: "Cloud", mesh: ProceduralGeometry.sphere(radius: 1, segments: 16))
        cloud.scale = [1.7, 0.55, 0.6]
        cloud.parent = 0
        var puff = ProceduralNode(name: "Puff", mesh: ProceduralGeometry.sphere(radius: 1, segments: 16))
        puff.scale = [3, 1, 1]
        let model = ProceduralModel(materials: [ProceduralMaterial(name: "Default")], nodes: [group, cloud, puff])

        let baked = model.bakingLeafScales()
        #expect(baked.nodes[1].scale == .one && baked.nodes[2].scale == .one)
        #expect(baked.nodes[0].scale == SIMD3<Float>(2, 2, 2), "a parent keeps its scale")
        let mesh = try #require(baked.nodes[2].mesh)
        #expect(abs((mesh.positions.map(\.x).max() ?? 0) - 3) < 1e-4)
        #expect(abs((mesh.positions.map(\.y).max() ?? 0) - 1) < 1e-4)
        #expect(mesh.normals.allSatisfy { abs(vecLength($0) - 1) < 1e-4 })
        // The pole of a stretched sphere still faces straight up, and the stretched equator faces along the long axis.
        let top = try #require(mesh.positions.indices.max { mesh.positions[$0].y < mesh.positions[$1].y })
        #expect(mesh.normals[top].y > 0.99)
        // Every triangle still faces outward after scaling.
        for start in stride(from: 0, to: mesh.indices.count, by: 3) {
            let corners = (0..<3).map { Int(mesh.indices[start + $0]) }
            let face = vecCross(mesh.positions[corners[1]] - mesh.positions[corners[0]], mesh.positions[corners[2]] - mesh.positions[corners[0]])
            let centroid = corners.map { mesh.positions[$0] }.reduce(SIMD3<Float>.zero, +)
            #expect((face * centroid).sum() > 0)
        }

        let imported = try NativeGLTFLoader().load(data: GLBWriter().encode(model))
        let meshIndex = try #require(imported.nodes[2].meshIndex)
        let primitive = try #require(imported.meshes[meshIndex].primitives.first)
        let positions = try #require(primitive.attributes[.position]?.vector3Values())
        #expect(abs((positions.map(\.x).max() ?? 0) - 3) < 1e-4, "the exported mesh carries the baked scale")
    }

    @Test("Mirrored, singular and nonfinite leaf scales preserve the original mesh and transform", arguments: [
        SIMD3<Float>(-2, 1, 3), SIMD3<Float>(2, -1, 3), SIMD3<Float>(2, 1, -3),
        SIMD3<Float>(-2, -1, 3), SIMD3<Float>(-2, -1, -3),
        SIMD3<Float>(0, 1, 3), SIMD3<Float>(2, 0, 3), SIMD3<Float>(2, 1, 0),
        SIMD3<Float>(.infinity, 1, 3), SIMD3<Float>(2, -.infinity, 3), SIMD3<Float>(2, 1, .nan),
    ])
    func preservesUnsupportedLeafScale(scale: SIMD3<Float>) {
        var node = ProceduralNode(name: "Leaf", mesh: ProceduralGeometry.box(width: 1, height: 2, depth: 3))
        node.scale = scale
        let model = ProceduralModel(materials: [ProceduralMaterial(name: "Default")], nodes: [node])

        let baked = model.bakingLeafScales()
        #expect(baked.nodes[0].mesh == node.mesh)
        for axis in 0..<3 {
            if scale[axis].isNaN {
                #expect(baked.nodes[0].scale[axis].isNaN)
            } else {
                #expect(baked.nodes[0].scale[axis] == scale[axis])
            }
        }
    }

    @Test("GLB output preserves mirrored and singular leaf transforms and geometry", arguments: [
        SIMD3<Float>(-2, 1, 3), SIMD3<Float>(-2, -1, 3), SIMD3<Float>(-2, -1, -3),
        SIMD3<Float>(0, 1, 3), SIMD3<Float>(2, 0, 3), SIMD3<Float>(2, 1, 0),
    ])
    func unsupportedScaleRoundTrip(scale: SIMD3<Float>) throws {
        let mesh = ProceduralGeometry.box(width: 1, height: 2, depth: 3)
        var node = ProceduralNode(name: "Leaf", mesh: mesh)
        node.scale = scale
        let model = ProceduralModel(materials: [ProceduralMaterial(name: "Default")], nodes: [node])

        let imported = try NativeGLTFLoader().load(data: GLBWriter().encode(model))
        let importedNode = try #require(imported.nodes.first)
        let restPose = try #require(importedNode.restPose)
        #expect(restPose.scale.x == scale.x && restPose.scale.y == scale.y && restPose.scale.z == scale.z)
        let meshIndex = try #require(importedNode.meshIndex)
        let primitive = try #require(imported.meshes[meshIndex].primitives.first)
        #expect(primitive.attributes[.position]?.values == mesh.positions.flatMap { [$0.x, $0.y, $0.z] })
        #expect(primitive.attributes[.normal]?.values == mesh.normals.flatMap { [$0.x, $0.y, $0.z] })
        #expect(primitive.indices == mesh.indices)
    }

    @Test("Models without geometry, with bad parents or bad materials are rejected")
    func invalidModels() {
        let material = ProceduralMaterial(name: "Default")
        #expect(throws: GLBWritingError.noGeometry) { try GLBWriter().encode(ProceduralModel(materials: [material], nodes: [ProceduralNode(name: "Empty")])) }
        var orphan = ProceduralNode(name: "Orphan", mesh: ProceduralGeometry.plane(width: 1, depth: 1))
        orphan.parent = 3
        #expect(throws: GLBWritingError.invalidParent(node: 0)) { try GLBWriter().encode(ProceduralModel(materials: [material], nodes: [orphan])) }
        var painted = ProceduralNode(name: "Painted", mesh: ProceduralGeometry.plane(width: 1, depth: 1))
        painted.material = 4
        #expect(throws: GLBWritingError.invalidMaterial(node: 0)) { try GLBWriter().encode(ProceduralModel(materials: [material], nodes: [painted])) }
    }
}

private func vecDot2(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float { (a * b).sum() }
