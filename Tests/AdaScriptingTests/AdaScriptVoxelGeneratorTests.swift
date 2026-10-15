import AdaAssets
@testable import AdaScripting
import Testing

@Suite("AdaScript voxel generator", .serialized)
@MainActor
struct AdaScriptVoxelGeneratorTests {
    @Test("Paints primitives with a custom palette and round-trips through the VOX loader")
    func generatesAndRoundTrips() throws {
        let result = try AdaScriptVoxelGenerator.generate(
            source: """
            func build(model) {
                model.size(8, 8, 8);
                model.palette(1, 200, 30, 30);
                model.palette(2, 20, 90, 220);
                model.box(0, 0, 0, 7, 7, 0, 1);
                model.sphere(4, 4, 4, 2, 2);
                model.voxel(0, 0, 7, 1);
                model.voxel(0, 0, 7, 0);
            }
            """
        )
        #expect((result.model.sizeX, result.model.sizeY, result.model.sizeZ) == (8, 8, 8))
        #expect(result.model.voxels.filter { $0.z == 0 && $0.colorIndex == 1 }.count == 64)
        #expect(result.model.voxels.contains(VOXVoxel(x: 4, y: 4, z: 4, colorIndex: 2)))
        #expect(!result.model.voxels.contains { $0.x == 0 && $0.y == 0 && $0.z == 7 })
        #expect(result.palette.color(forIndex: 1) == VOXColor(red: 200, green: 30, blue: 30))

        let data = try VOXWriter().encode(model: result.model, palette: result.palette)
        let file = try VOXLoader().load(data: data)
        #expect(file.models == [result.model])
        #expect(file.palette == result.palette)
        #expect(file.hasCustomPalette)
    }

    @Test("Loops run inside the script")
    func loopsPaintVoxels() throws {
        let result = try AdaScriptVoxelGenerator.generate(
            source: """
            func build(model) {
                model.size(4, 4, 4);
                for (var i in 0...3) {
                    model.voxel(i, i, i, 1);
                }
                model.voxel(3, 0, 0, 1);
            }
            """
        )
        #expect(result.model.voxels.count == 5)
    }

    @Test("Rejects invalid scripts", arguments: [
        "func build(model) { model.voxel(0, 0, 0, 1); }",
        "func build(model) { model.size(2, 2, 2); }",
        "func build(model) { model.size(300, 2, 2); }",
        "func build(model) { model.size(2, 2, 2); model.voxel(5, 0, 0, 1); }",
        "func build(model) { model.size(2, 2, 2); model.voxel(0, 0, 0, 999); }",
        "func build(model) { model.size(2, 2, 2); model.voxel(0.5, 0, 0, 1); }",
        "func other(model) { }",
        "func build(model) { System.exit(1); }",
        "func build(model) { while (true) { } }"
    ])
    func rejectsInvalid(source: String) {
        #expect(throws: (any Error).self) { try AdaScriptVoxelGenerator.generate(source: source) }
    }
}
