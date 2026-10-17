import AdaNavigation
import AdaNavigationBaking
import Foundation
import Math
import Testing

@Suite("Navigation asset persistence")
struct NavigationAssetTests {
    @Test("A persisted bake loads without Recast and returns the same route and debug mesh")
    func roundTrip() async throws {
        let bake = try await data()
        let original = try NavigationMesh(data: bake)
        let loadedData = try NavigationMeshData(encoded: bake.encoded())
        let loaded = try NavigationMesh(data: loadedData)
        let first = try await original.findPath(from: [1, 0, 1], to: [9, 0, 9])
        let second = try await loaded.findPath(from: [1, 0, 1], to: [9, 0, 9])
        #expect(first.points == second.points)
        #expect(bake.agent == loadedData.agent)
        #expect(bake.polygonCount == loadedData.polygonCount)
        let triangles = try await loaded.debugTriangles()
        #expect(!triangles.isEmpty)
        #expect(triangles.count.isMultiple(of: 3))
        #expect(triangles.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
    }

    @Test("Unsupported versions and mismatched metadata are rejected")
    func metadata() async throws {
        let encoded = try await data().encoded()
        var json = try object(encoded)
        json["version"] = 2
        #expect(throws: NavigationError.unsupportedAssetVersion) {
            try NavigationMeshData(encoded: JSONSerialization.data(withJSONObject: json))
        }
        json = try object(encoded)
        json["polygonCount"] = 500
        #expect(throws: NavigationError.invalidAsset) {
            try NavigationMeshData(encoded: JSONSerialization.data(withJSONObject: json))
        }
        json = try object(encoded)
        var agent = try #require(json["agent"] as? [String: Any])
        agent["radius"] = 0.1
        json["agent"] = agent
        #expect(throws: NavigationError.invalidAsset) {
            try NavigationMeshData(encoded: JSONSerialization.data(withJSONObject: json))
        }
    }

    @Test("Truncation, huge counts, invalid references and NaN vertices fail before native loading")
    func corruptedTile() async throws {
        let encoded = try await data().encoded()
        let json = try object(encoded)
        let tileString = try #require(json["tile"] as? String)
        let tile = try #require(Data(base64Encoded: tileString))
        var variants = [Data(tile.prefix(tile.count - 1)), Data(tile.prefix(12))]
        var countOverflow = tile
        // dtMeshHeader.polyCount follows magic/version/x/y/layer/userId.
        countOverflow.replaceSubrange(24..<28, with: [255, 255, 255, 127])
        variants.append(countOverflow)
        var invalidVertex = tile
        // Header is 100 bytes in the pinned layout. Inject NaN into the first vertex.
        invalidVertex.replaceSubrange(100..<104, with: [0, 0, 192, 127])
        variants.append(invalidVertex)
        let vertexCount = (0..<4).reduce(UInt32(0)) { $0 | UInt32(tile[28 + $1]) << ($1 * 8) }
        let polygonStart = 100 + Int(vertexCount) * 12
        var invalidReference = tile
        invalidReference.replaceSubrange((polygonStart + 4)..<(polygonStart + 6), with: [255, 255])
        variants.append(invalidReference)
        var invalidNeighbor = tile
        invalidNeighbor.replaceSubrange((polygonStart + 16)..<(polygonStart + 18), with: [255, 255])
        variants.append(invalidNeighbor)
        for variant in variants {
            var changed = json
            changed["tile"] = variant.base64EncodedString()
            #expect(throws: NavigationError.invalidAsset) {
                try NavigationMeshData(encoded: JSONSerialization.data(withJSONObject: changed))
            }
        }
    }

    private func data() async throws -> NavigationMeshData {
        try await NavigationMeshBaker.bake(
            vertices: [[0, 0, 0], [0, 0, 10], [10, 0, 10], [10, 0, 0]], indices: [0, 1, 2, 0, 2, 3]
        )
    }

    private func object(_ data: Data) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
