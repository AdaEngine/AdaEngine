import AdaAssets
import Foundation
import Math
import Testing

/// A one-triangle glTF with two morph targets, built from a data URI so every case is a few edits of the JSON.
private struct MorphGLTFFixture {
    var meshWeights: [Float]? = [0.25, 0.75]
    var targetNames: [String]? = ["smile", "blink"]
    var nodeWeights: [Float]?
    var nodeMatrix: [Float]?
    var secondPrimitiveTargetCount: Int?
    var targetAttributes: [[String: Int]]?
    var sparseFirstTarget = false
    var animation: [String: Any]?

    // Layout: 0 positions, 1 target 0 positions, 2 target 1 positions, 3 target 1 normals, 4 times, 5 weights (2 keys x 2 targets),
    // 6 sparse indices, 7 sparse values.
    static let positions: [Float] = [0, 0, 0, 1, 0, 0, 0, 1, 0]
    static let target0: [Float] = [0, 0.5, 0, 0, 0.5, 0, 0, 0.5, 0]
    static let target1: [Float] = [1, 0, 0, 1, 0, 0, 1, 0, 0]
    static let target1Normals: [Float] = [0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1]
    static let times: [Float] = [0, 1]
    static let weightKeys: [Float] = [0, 1, 1, 0]

    func data() throws -> Data {
        var bytes = Data()
        var views: [[String: Any]] = []
        func add(_ floats: [Float]) {
            var chunk = Data()
            for value in floats { withUnsafeBytes(of: value.bitPattern.littleEndian) { chunk.append(contentsOf: $0) } }
            views.append(["buffer": 0, "byteOffset": bytes.count, "byteLength": chunk.count])
            bytes.append(chunk)
        }
        add(Self.positions)
        add(Self.target0)
        add(Self.target1)
        add(Self.target1Normals)
        add(Self.times)
        add(animation?["values"] as? [Float] ?? Self.weightKeys)
        // Sparse: vertex 1 of the first target is displaced by (0, 2, 0); the rest stays zero.
        var indices = Data()
        withUnsafeBytes(of: UInt16(1).littleEndian) { indices.append(contentsOf: $0) }
        views.append(["buffer": 0, "byteOffset": bytes.count, "byteLength": 2])
        bytes.append(indices)
        while bytes.count % 4 != 0 { bytes.append(0) }
        add([0, 2, 0])

        func accessor(_ view: Int, _ count: Int, _ type: String) -> [String: Any] {
            ["bufferView": view, "componentType": 5126, "count": count, "type": type]
        }
        var accessors: [[String: Any]] = [
            accessor(0, 3, "VEC3"), accessor(1, 3, "VEC3"), accessor(2, 3, "VEC3"), accessor(3, 3, "VEC3"),
            accessor(4, 2, "SCALAR"), accessor(5, animation?["count"] as? Int ?? 4, "SCALAR"),
            [
                "componentType": 5126, "count": 3, "type": "VEC3",
                "sparse": ["count": 1, "indices": ["bufferView": 6, "componentType": 5123], "values": ["bufferView": 7]],
            ],
        ]
        accessors[0]["min"] = [0, 0, 0]
        accessors[0]["max"] = [1, 1, 0]

        let targets = targetAttributes ?? [
            ["POSITION": sparseFirstTarget ? 6 : 1],
            ["POSITION": 2, "NORMAL": 3],
        ]
        var primitive: [String: Any] = ["attributes": ["POSITION": 0], "targets": targets]
        var primitives: [[String: Any]] = [primitive]
        if let count = secondPrimitiveTargetCount {
            primitive["targets"] = Array(repeating: ["POSITION": 1], count: count)
            primitives.append(primitive)
        }
        var mesh: [String: Any] = ["primitives": primitives]
        if let meshWeights { mesh["weights"] = meshWeights }
        if let targetNames { mesh["extras"] = ["targetNames": targetNames] }
        var node: [String: Any] = ["mesh": 0]
        if let nodeWeights { node["weights"] = nodeWeights }
        if let nodeMatrix { node["matrix"] = nodeMatrix }

        var document: [String: Any] = [
            "asset": ["version": "2.0"],
            "buffers": [["byteLength": bytes.count, "uri": "data:application/octet-stream;base64," + bytes.base64EncodedString()]],
            "bufferViews": views,
            "accessors": accessors,
            "meshes": [mesh],
            "nodes": [node],
            "scenes": [["nodes": [0]]],
        ]
        if let animation {
            document["animations"] = [[
                "samplers": [["input": 4, "output": 5, "interpolation": animation["interpolation"] as? String ?? "LINEAR"]],
                "channels": [["sampler": 0, "target": ["node": animation["node"] as? Int ?? 0, "path": "weights"]]],
            ]]
        }
        return try JSONSerialization.data(withJSONObject: document)
    }
}

@Suite
struct GLTFMorphTargetImportTests {
    @Test
    func importsTargetsWeightsAndNames() throws {
        let result = try NativeGLTFLoader().load(data: MorphGLTFFixture().data())
        let mesh = try #require(result.meshes.first)
        #expect(mesh.morphTargetCount == 2)
        #expect(mesh.defaultWeights == [0.25, 0.75] && mesh.targetNames == ["smile", "blink"])
        let targets = try #require(mesh.primitives.first).morphTargets
        #expect(targets[0].positionDeltas == [Vector3(0, 0.5, 0), Vector3(0, 0.5, 0), Vector3(0, 0.5, 0)])
        #expect(targets[0].normalDeltas.isEmpty && targets[0].tangentDeltas.isEmpty, "A target without NORMAL leaves normals alone.")
        #expect(targets[1].positionDeltas.count == 3 && targets[1].positionDeltas[0] == Vector3(1, 0, 0))
        #expect(targets[1].normalDeltas.first == Vector3(0, 0, 0.1))
        #expect(result.warnings.isEmpty)
    }

    @Test
    func meshesWithoutTargetsHaveNoMorphData() throws {
        var fixture = MorphGLTFFixture()
        fixture.targetAttributes = []
        fixture.meshWeights = nil
        fixture.targetNames = nil
        let result = try NativeGLTFLoader().load(data: fixture.data())
        #expect(result.meshes[0].morphTargetCount == 0 && result.meshes[0].defaultWeights.isEmpty)
        #expect(result.meshes[0].primitives[0].morphTargets.isEmpty)
    }

    @Test
    func missingWeightsDefaultToZero() throws {
        var fixture = MorphGLTFFixture()
        fixture.meshWeights = nil
        fixture.targetNames = nil
        let mesh = try #require(NativeGLTFLoader().load(data: fixture.data()).meshes.first)
        #expect(mesh.defaultWeights == [0, 0] && mesh.targetNames.isEmpty)
    }

    @Test
    func sparseTargetAccessorsExpandToDenseDeltas() throws {
        var fixture = MorphGLTFFixture()
        fixture.sparseFirstTarget = true
        let target = try #require(NativeGLTFLoader().load(data: fixture.data()).meshes[0].primitives[0].morphTargets.first)
        #expect(target.positionDeltas == [.zero, Vector3(0, 2, 0), .zero])
    }

    @Test
    func nodeWeightsOverrideTheMeshWeights() throws {
        var fixture = MorphGLTFFixture()
        fixture.nodeWeights = [1, 0]
        let result = try NativeGLTFLoader().load(data: fixture.data())
        #expect(result.nodes[0].weights == [1, 0] && result.meshes[0].defaultWeights == [0.25, 0.75])
        #expect(try NativeGLTFLoader().load(data: MorphGLTFFixture().data()).nodes[0].weights == nil)
    }

    @Test
    func rejectsNodeWeightsThatDoNotMatchTheTargets() throws {
        var fixture = MorphGLTFFixture()
        fixture.nodeWeights = [1]
        let data = try fixture.data()
        #expect(throws: NativeGLTFLoader.GLTFError.invalidNode(0)) { try NativeGLTFLoader().load(data: data) }
    }

    @Test(arguments: ["meshWeights", "names", "primitiveCount", "accessorCount", "withoutPositions"])
    func rejectsInconsistentMorphData(kind: String) throws {
        var fixture = MorphGLTFFixture()
        switch kind {
        case "meshWeights": fixture.meshWeights = [1, 2, 3]
        case "names": fixture.targetNames = ["only one"]
        case "primitiveCount": fixture.secondPrimitiveTargetCount = 1
        case "accessorCount": fixture.targetAttributes = [["POSITION": 4]]
        default: break
        }
        var data = try fixture.data()
        if kind == "withoutPositions" {
            var document = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            var meshes = try #require(document["meshes"] as? [[String: Any]])
            var primitives = try #require(meshes[0]["primitives"] as? [[String: Any]])
            primitives[0]["attributes"] = ["NORMAL": 3]
            meshes[0]["primitives"] = primitives
            document["meshes"] = meshes
            data = try JSONSerialization.data(withJSONObject: document)
        }
        let loaded = data
        #expect(throws: NativeGLTFLoader.GLTFError.invalidMorphTargets(0)) { try NativeGLTFLoader().load(data: loaded) }
    }

    @Test
    func morphedAttributesOtherThanPositionNormalAndTangentAreReported() throws {
        var fixture = MorphGLTFFixture()
        fixture.targetAttributes = [["POSITION": 1, "TEXCOORD_0": 1], ["POSITION": 2]]
        let result = try NativeGLTFLoader().load(data: fixture.data())
        #expect(result.warnings.count == 1 && result.warnings[0].contains("TEXCOORD_0") && result.warnings[0].contains("Mesh 0"))
        #expect(result.meshes[0].primitives[0].morphTargets[0].positionDeltas.count == 3)
    }

    @Test(arguments: ["LINEAR", "STEP"])
    func importsAnimatedWeights(interpolation: String) throws {
        var fixture = MorphGLTFFixture()
        fixture.animation = ["interpolation": interpolation]
        let result = try NativeGLTFLoader().load(data: fixture.data())
        let animation = try #require(result.animations.first)
        #expect(animation.channels[0].path == .weights && animation.channels[0].nodeIndex == 0)
        #expect(animation.samplers[0].times == [0, 1])
        #expect(animation.samplers[0].output.values == [0, 1, 1, 0], "Two keys of two target weights.")
        #expect(animation.samplers[0].interpolation.rawValue == interpolation)
    }

    @Test
    func cubicWeightSamplersCarryTangents() throws {
        var fixture = MorphGLTFFixture()
        let values = [Float](repeating: 0.5, count: 12)
        fixture.animation = ["interpolation": "CUBICSPLINE", "values": values, "count": 12]
        let sampler = try #require(NativeGLTFLoader().load(data: fixture.data()).animations.first?.samplers.first)
        #expect(sampler.output.values.count == 12, "In-tangent, value and out-tangent for each of two targets at each of two keys.")
    }

    @Test
    func weightChannelsAreValidOnMatrixNodesButNeedTargets() throws {
        var fixture = MorphGLTFFixture()
        fixture.animation = [:]
        fixture.nodeMatrix = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
        #expect(try NativeGLTFLoader().load(data: fixture.data()).animations.count == 1)
        fixture.animation = ["count": 6, "values": [Float](repeating: 0, count: 6)]
        let wrongCount = try fixture.data()
        #expect(throws: NativeGLTFLoader.GLTFError.invalidAnimation(0)) { try NativeGLTFLoader().load(data: wrongCount) }
        var untargeted = MorphGLTFFixture()
        untargeted.targetAttributes = []
        untargeted.meshWeights = nil
        untargeted.targetNames = nil
        untargeted.animation = [:]
        let withoutTargets = try untargeted.data()
        #expect(throws: NativeGLTFLoader.GLTFError.invalidAnimation(0)) { try NativeGLTFLoader().load(data: withoutTargets) }
    }
}
