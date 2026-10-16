import AdaAssets
import Testing

@Suite
struct VOXWriterTests {
    @Test
    func roundTripsThroughLoader() throws {
        var colors = VOXPalette.fallback.colors
        colors[0] = VOXColor(red: 10, green: 20, blue: 30, alpha: 255)
        colors[254] = VOXColor(red: 1, green: 2, blue: 3, alpha: 128)
        let palette = VOXPalette(colors: colors)
        let model = VOXModel(
            sizeX: 256, sizeY: 3, sizeZ: 4,
            voxels: [VOXVoxel(x: 0, y: 0, z: 0, colorIndex: 1), VOXVoxel(x: 255, y: 2, z: 3, colorIndex: 255)]
        )
        let file = try VOXLoader().load(data: VOXWriter().encode(model: model, palette: palette))
        #expect(file.version == 150)
        #expect(file.models == [model])
        #expect(file.palette == palette)
    }

    @Test
    func rejectsInvalidModels() {
        let palette = VOXPalette.fallback
        let voxel = VOXVoxel(x: 0, y: 0, z: 0, colorIndex: 1)
        #expect(throws: VOXWritingError.invalidSize(x: 257, y: 1, z: 1)) {
            try VOXWriter().encode(model: VOXModel(sizeX: 257, sizeY: 1, sizeZ: 1, voxels: []), palette: palette)
        }
        #expect(throws: VOXWritingError.invalidVoxel(index: 0)) {
            try VOXWriter().encode(model: VOXModel(sizeX: 1, sizeY: 1, sizeZ: 1, voxels: [VOXVoxel(x: 1, y: 0, z: 0, colorIndex: 1)]), palette: palette)
        }
        #expect(throws: VOXWritingError.invalidVoxel(index: 0)) {
            try VOXWriter().encode(model: VOXModel(sizeX: 1, sizeY: 1, sizeZ: 1, voxels: [VOXVoxel(x: 0, y: 0, z: 0, colorIndex: 0)]), palette: palette)
        }
        #expect(throws: VOXWritingError.invalidPalette) {
            try VOXWriter().encode(model: VOXModel(sizeX: 1, sizeY: 1, sizeZ: 1, voxels: [voxel]), palette: VOXPalette(colors: []))
        }
    }
}
