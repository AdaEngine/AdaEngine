import AdaAssets
import Foundation
import Testing

@Suite
struct VOXLoaderTests {
    @Test
    func loadsModelAndPalette() throws {
        let palette = (0..<256).map { VOXColor(red: UInt8($0), green: 10, blue: 20, alpha: 255) }
        let file = try VOXLoader().load(
            data: VOXBuilder.file(
                chunks: [
                    VOXBuilder.size(2, 3, 4),
                    VOXBuilder.xyzi([(0, 0, 0, 1), (1, 2, 3, 5)]),
                    VOXBuilder.rgba(palette)
                ]
            )
        )

        #expect(file.version == 150)
        #expect(file.models.count == 1)
        let model = try #require(file.models.first)
        #expect((model.sizeX, model.sizeY, model.sizeZ) == (2, 3, 4))
        #expect(model.voxels == [
            VOXVoxel(x: 0, y: 0, z: 0, colorIndex: 1),
            VOXVoxel(x: 1, y: 2, z: 3, colorIndex: 5)
        ])
        #expect(file.hasCustomPalette)
        // Index n maps to colors[n - 1].
        #expect(file.palette.color(forIndex: 1) == palette[0])
        #expect(file.palette.color(forIndex: 5) == palette[4])
        #expect(file.palette.color(forIndex: 0) == nil)
        #expect(file.nodes.isEmpty)
    }

    @Test
    func usesFallbackPaletteWithoutRGBAChunk() throws {
        let file = try VOXLoader().load(
            data: VOXBuilder.file(chunks: [VOXBuilder.size(1, 1, 1), VOXBuilder.xyzi([(0, 0, 0, 1)])])
        )
        #expect(!file.hasCustomPalette)
        #expect(file.palette.colors.count == 256)
    }

    @Test
    func skipsUnknownChunks() throws {
        let file = try VOXLoader().load(
            data: VOXBuilder.file(
                chunks: [
                    VOXBuilder.chunk("rOBJ", VOXBuilder.dictionary(["_type": "_setting"])),
                    VOXBuilder.size(1, 1, 1),
                    VOXBuilder.xyzi([(0, 0, 0, 3)])
                ]
            )
        )
        #expect(file.models.count == 1)
    }

    @Test
    func parsesSceneGraphWithRotationAndTranslation() throws {
        // Rotation packed 0b0010_0100 | index0=0, index1=1 (identity) with row 1 negated.
        let packed = String(0b0010_0100 as UInt8)
        let file = try VOXLoader().load(
            data: VOXBuilder.file(
                chunks: [
                    VOXBuilder.size(1, 1, 1),
                    VOXBuilder.xyzi([(0, 0, 0, 1)]),
                    VOXBuilder.transform(
                        id: 0,
                        attributes: [:],
                        child: 1,
                        layer: -1,
                        frames: [[:]]
                    ),
                    VOXBuilder.group(id: 1, children: [2]),
                    VOXBuilder.transform(
                        id: 2,
                        attributes: ["_name": "arm"],
                        child: 3,
                        layer: 0,
                        frames: [["_r": packed, "_t": "4 -5 6"]]
                    ),
                    VOXBuilder.shape(id: 3, models: [0]),
                    VOXBuilder.layer(id: 0, name: "Layer0", hidden: false)
                ]
            )
        )

        #expect(file.nodes.count == 4)
        guard case .transform(let root)? = file.rootNode else {
            Issue.record("Root should be a transform node")
            return
        }
        #expect(root.childID == 1)
        #expect(!root.isAnimated)

        guard case .group(let group)? = file.nodes[1] else {
            Issue.record("Node 1 should be a group")
            return
        }
        #expect(group.childIDs == [2])

        guard case .transform(let arm)? = file.nodes[2] else {
            Issue.record("Node 2 should be a transform")
            return
        }
        #expect(arm.name == "arm")
        let frame = try #require(arm.frames.first)
        #expect(frame.translation == SIMD3(4, -5, 6))
        #expect(frame.rotation.apply(x: 1, y: 2, z: 3) == SIMD3(1, -2, 3))

        guard case .shape(let shape)? = file.nodes[3] else {
            Issue.record("Node 3 should be a shape")
            return
        }
        #expect(shape.models.map(\.modelIndex) == [0])
        #expect(file.layers == [VOXLayer(id: 0, name: "Layer0", isHidden: false)])
    }

    @Test
    func reportsAnimatedTransformAndShape() throws {
        let file = try VOXLoader().load(
            data: VOXBuilder.file(
                chunks: [
                    VOXBuilder.size(1, 1, 1),
                    VOXBuilder.xyzi([(0, 0, 0, 1)]),
                    VOXBuilder.size(1, 1, 1),
                    VOXBuilder.xyzi([(0, 0, 0, 2)]),
                    VOXBuilder.transform(
                        id: 0,
                        attributes: [:],
                        child: 1,
                        layer: -1,
                        frames: [["_t": "0 0 0", "_f": "0"], ["_t": "0 0 2", "_f": "10"]]
                    ),
                    VOXBuilder.shape(id: 1, models: [0, 1], modelFrames: ["0", "5"])
                ]
            )
        )

        guard case .transform(let transform)? = file.rootNode, case .shape(let shape)? = file.nodes[1] else {
            Issue.record("Unexpected node kinds")
            return
        }
        #expect(transform.isAnimated)
        #expect(transform.frames.map(\.frameIndex) == [0, 10])
        #expect(shape.isAnimated)
        #expect(shape.models.map(\.frameIndex) == [0, 5])
        #expect(file.models.count == 2)
    }

    @Test
    func parsesMaterials() throws {
        let file = try VOXLoader().load(
            data: VOXBuilder.file(
                chunks: [
                    VOXBuilder.size(1, 1, 1),
                    VOXBuilder.xyzi([(0, 0, 0, 1)]),
                    VOXBuilder.material(id: 1, properties: ["_type": "_metal", "_rough": "0.25"])
                ]
            )
        )
        let material = try #require(file.materials.first)
        #expect(material.paletteIndex == 1)
        #expect(material.type == "_metal")
        #expect(material.number("_rough") == 0.25)
    }

    @Test
    func decodesAllRotationsAsValidAxisPermutations() {
        var valid = 0
        for packed in UInt8(0)..<128 {
            guard let rotation = VOXRotation(packed: packed) else {
                continue
            }
            valid += 1
            let image = rotation.apply(x: 1, y: 2, z: 3)
            #expect(Set([abs(image.x), abs(image.y), abs(image.z)]) == [1, 2, 3])
        }
        // 3 choices * 2 remaining choices * 8 sign combinations.
        #expect(valid == 48)
        #expect(VOXRotation(packed: 4) == .identity)
    }

    @Test
    func rejectsInvalidHeader() {
        #expect(throws: VOXLoadingError.invalidHeader) {
            try VOXLoader().load(data: Data("NOPE".utf8) + Data(repeating: 0, count: 16))
        }
    }

    @Test
    func rejectsUnsupportedVersion() {
        #expect(throws: VOXLoadingError.unsupportedVersion(100)) {
            try VOXLoader().load(data: VOXBuilder.file(version: 100, chunks: []))
        }
    }

    @Test
    func rejectsTruncatedData() throws {
        let data = VOXBuilder.file(chunks: [VOXBuilder.size(2, 2, 2), VOXBuilder.xyzi([(0, 0, 0, 1), (1, 1, 1, 2)])])
        #expect(throws: VOXLoadingError.truncated) {
            try VOXLoader().load(data: data.prefix(data.count - 3))
        }
    }

    @Test
    func rejectsVoxelOutsideModelBounds() {
        let data = VOXBuilder.file(chunks: [VOXBuilder.size(2, 2, 2), VOXBuilder.xyzi([(2, 0, 0, 1)])])
        #expect(throws: VOXLoadingError.invalidModel(index: 0)) {
            try VOXLoader().load(data: data)
        }
    }

    @Test
    func rejectsInvalidRotationAttribute() {
        let data = VOXBuilder.file(
            chunks: [
                VOXBuilder.transform(id: 0, attributes: [:], child: 1, layer: -1, frames: [["_r": "0"]])
            ]
        )
        #expect(throws: VOXLoadingError.invalidAttribute(key: "_r", value: "0")) {
            try VOXLoader().load(data: data)
        }
    }
}

/// Builds `.vox` binary data for tests.
private enum VOXBuilder {
    static func int32(_ value: Int) -> Data {
        var raw = UInt32(bitPattern: Int32(value)).littleEndian
        return withUnsafeBytes(of: &raw) { Data($0) }
    }

    static func string(_ value: String) -> Data {
        int32(value.utf8.count) + Data(value.utf8)
    }

    static func dictionary(_ values: [String: String]) -> Data {
        values.sorted { $0.key < $1.key }.reduce(int32(values.count)) { data, pair in
            data + string(pair.key) + string(pair.value)
        }
    }

    static func chunk(_ id: String, _ content: Data, children: Data = Data()) -> Data {
        Data(id.utf8) + int32(content.count) + int32(children.count) + content + children
    }

    static func file(version: Int = 150, chunks: [Data]) -> Data {
        let children = chunks.reduce(Data()) { $0 + $1 }
        return Data("VOX ".utf8) + int32(version) + chunk("MAIN", Data(), children: children)
    }

    static func size(_ x: Int, _ y: Int, _ z: Int) -> Data {
        chunk("SIZE", int32(x) + int32(y) + int32(z))
    }

    static func xyzi(_ voxels: [(UInt8, UInt8, UInt8, UInt8)]) -> Data {
        let body = voxels.reduce(int32(voxels.count)) { $0 + Data([$1.0, $1.1, $1.2, $1.3]) }
        return chunk("XYZI", body)
    }

    static func rgba(_ colors: [VOXColor]) -> Data {
        chunk("RGBA", colors.reduce(Data()) { $0 + Data([$1.red, $1.green, $1.blue, $1.alpha]) })
    }

    static func material(id: Int, properties: [String: String]) -> Data {
        chunk("MATL", int32(id) + dictionary(properties))
    }

    static func layer(id: Int, name: String, hidden: Bool) -> Data {
        var attributes = ["_name": name]
        if hidden {
            attributes["_hidden"] = "1"
        }
        return chunk("LAYR", int32(id) + dictionary(attributes) + int32(-1))
    }

    static func transform(id: Int, attributes: [String: String], child: Int, layer: Int, frames: [[String: String]]) -> Data {
        var body = int32(id) + dictionary(attributes) + int32(child) + int32(-1) + int32(layer) + int32(frames.count)
        for frame in frames {
            body += dictionary(frame)
        }
        return chunk("nTRN", body)
    }

    static func group(id: Int, children: [Int]) -> Data {
        let body = children.reduce(int32(id) + dictionary([:]) + int32(children.count)) { $0 + int32($1) }
        return chunk("nGRP", body)
    }

    static func shape(id: Int, models: [Int], modelFrames: [String]? = nil) -> Data {
        var body = int32(id) + dictionary([:]) + int32(models.count)
        for (index, model) in models.enumerated() {
            body += int32(model) + dictionary(modelFrames.map { ["_f": $0[index]] } ?? [:])
        }
        return chunk("nSHP", body)
    }
}
