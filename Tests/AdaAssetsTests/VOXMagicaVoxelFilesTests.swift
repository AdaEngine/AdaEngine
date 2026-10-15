import AdaAssets
import Foundation
import Testing

/// Files saved by MagicaVoxel 0.99.7.2 itself (format version 200); see `Fixtures/vox/magicavoxel/README.md`.
@Suite
struct VOXMagicaVoxelFilesTests {
    private func load(_ name: String) async throws -> VOXFile {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/vox/magicavoxel/\(name).vox")
        return try await VOXLoader().load(url: url)
    }

    @Test
    func readsTheKnight() async throws {
        let file = try await load("chr_knight")

        #expect(file.version == 200)
        let model = try #require(file.models.first)
        #expect(file.models.count == 1)
        #expect((model.sizeX, model.sizeY, model.sizeZ) == (20, 21, 20))
        #expect(model.voxels.count == 398)
        #expect(file.hasCustomPalette)
        #expect(file.palette.colors.count == 256)
        #expect(file.materials.count == 256)
        #expect(!file.layers.isEmpty)

        // Root transform, a group, then a transform that lifts the model by half its height onto the ground.
        guard case .transform(let placement)? = file.nodes[2] else {
            Issue.record("Node 2 should be the model's transform")
            return
        }
        #expect(placement.frames.first?.translation == SIMD3(0, 0, model.sizeZ / 2))
        #expect(placement.frames.first?.rotation == .identity)
        guard case .shape(let shape)? = file.nodes[3] else {
            Issue.record("Node 3 should be the shape")
            return
        }
        #expect(shape.models.map(\.modelIndex) == [0])
    }

    @Test
    func modelTranslationsAreItsPivotOnTheGround() async throws {
        // MagicaVoxel stores the model pivot as floor(size / 2), which puts the model's lowest cell on the ground.
        for name in ["chr_knight", "cars", "deer"] {
            let file = try await load(name)
            for node in file.nodes.values {
                guard case .transform(let transform) = node, transform.id != 0,
                    case .shape(let shape)? = file.nodes[transform.childID], let first = shape.models.first
                else {
                    continue
                }
                let model = file.models[first.modelIndex]
                if name != "cars" {
                    #expect(transform.frames.first?.translation.z == model.sizeZ / 2, Comment(rawValue: name))
                }
            }
        }
    }

    @Test
    func readsTheRotatedCar() async throws {
        let file = try await load("cars")

        #expect(file.models.count == 2)
        #expect(file.nodes.count == 6)
        guard case .transform(let police)? = file.nodes[2], case .transform(let wagon)? = file.nodes[4] else {
            Issue.record("Nodes 2 and 4 should be the two cars")
            return
        }

        let policeFrame = try #require(police.frames.first)
        #expect(policeFrame.translation == SIMD3(-28, 7, 6))
        // `_r = 17` turns the model a quarter turn about Z: its X axis becomes Y and Y becomes -X.
        #expect(policeFrame.rotation.apply(x: 1, y: 0, z: 0) == SIMD3(0, 1, 0))
        #expect(policeFrame.rotation.apply(x: 0, y: 1, z: 0) == SIMD3(-1, 0, 0))
        #expect(policeFrame.rotation.apply(x: 0, y: 0, z: 1) == SIMD3(0, 0, 1))

        let wagonFrame = try #require(wagon.frames.first)
        #expect(wagonFrame.translation == SIMD3(16, -11, 7))
        #expect(wagonFrame.rotation == .identity)
        #expect(file.models.map { ($0.sizeX, $0.sizeY, $0.sizeZ) }.map { [$0.0, $0.1, $0.2] } == [[15, 34, 13], [15, 32, 14]])
    }

    @Test
    func readsTheFrameByFrameDeer() async throws {
        let file = try await load("deer")

        #expect(file.models.count == 4)
        #expect(file.models.allSatisfy { ($0.sizeX, $0.sizeY, $0.sizeZ) == (26, 9, 27) })
        guard case .shape(let shape)? = file.nodes[3] else {
            Issue.record("Node 3 should be the animated shape")
            return
        }
        #expect(shape.isAnimated)
        #expect(shape.models.map(\.modelIndex) == [0, 1, 2, 3])
        #expect(shape.models.map(\.frameIndex) == [0, 1, 2, 3])
        // The transform above it is not keyed: only the model changes.
        guard case .transform(let placement)? = file.nodes[2] else {
            Issue.record("Node 2 should be the placement")
            return
        }
        #expect(!placement.isAnimated)
    }
}
