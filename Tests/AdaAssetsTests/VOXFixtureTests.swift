import AdaAssets
import Foundation
import Testing

/// Loads the `.vox` files produced by `script/generate_vox_fixtures.py`.
@Suite
struct VOXFixtureTests {
    private func fixture(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/vox/\(name).vox")
    }

    @Test
    func loadsCastleFixture() async throws {
        let file = try await VOXLoader().load(url: fixture("castle"))

        #expect(file.models.count == 1)
        let model = try #require(file.models.first)
        #expect((model.sizeX, model.sizeY, model.sizeZ) == (16, 16, 12))
        #expect(model.voxels.count > 500)
        #expect(file.hasCustomPalette)
        #expect(file.palette.color(forIndex: 1) == VOXColor(red: 200, green: 60, blue: 50))
        #expect(file.materials.first?.type == "_diffuse")
    }

    @Test
    func loadsRobotSceneGraphWithAnimatedArm() async throws {
        let file = try await VOXLoader().load(url: fixture("robot"))

        #expect(file.models.count == 3)
        let names = file.nodes.values.compactMap { node -> String? in
            if case .transform(let transform) = node {
                return transform.name
            }
            return nil
        }
        #expect(Set(names) == ["body", "head", "arm"])
        guard case .transform(let arm)? = file.nodes[6] else {
            Issue.record("Node 6 should be the arm transform")
            return
        }
        #expect(arm.isAnimated)
        #expect(arm.frames.map(\.frameIndex) == [0, 10])
        #expect(arm.frames.last?.rotation != .identity)
    }
}
