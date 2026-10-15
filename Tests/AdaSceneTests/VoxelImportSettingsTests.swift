import Foundation
import Testing
@testable import AdaScene

@Suite
struct VoxelImportSettingsTests {
    @Test
    func defaultsProduceNoQuery() {
        let settings = VoxelImportSettings()

        #expect(settings.isDefault)
        #expect(settings.assetQuery.isEmpty)
        #expect(settings.options.voxelSize == 0.1)
        #expect(!settings.options.mergeStatic)
        #expect(settings.options.framesPerSecond == 30)
    }

    @Test
    func queryRoundTripsNonDefaultValues() {
        let settings = VoxelImportSettings(voxelSize: 0.05, mergeStatic: true, framesPerSecond: 24)

        #expect(settings.assetQuery == "voxelSize=0.05&mergeStatic=1&fps=24.0")
        #expect(VoxelImportSettings(query: settings.assetQuery) == settings)
    }

    @Test
    func onlyChangedValuesAreWritten() {
        #expect(VoxelImportSettings(voxelSize: 0.25).assetQuery == "voxelSize=0.25")
        #expect(VoxelImportSettings(mergeStatic: true).assetQuery == "mergeStatic=1")
        #expect(VoxelImportSettings(framesPerSecond: 12).assetQuery == "fps=12.0")
    }

    @Test
    func parsesFlagsAndIgnoresInvalidValues() {
        #expect(VoxelImportSettings(query: "mergeStatic").mergeStatic)
        #expect(VoxelImportSettings(query: "mergeStatic=true").mergeStatic)
        #expect(!VoxelImportSettings(query: "mergeStatic=0").mergeStatic)

        for invalid in ["voxelSize=abc", "voxelSize=-1", "voxelSize=0", "voxelSize=nan", "voxelSize=inf", "voxelSize=100000", "voxelSize="] {
            #expect(VoxelImportSettings(query: invalid).voxelSize == 0.1, Comment(rawValue: invalid))
        }
        for invalid in ["fps=0", "fps=-3", "fps=x", "fps=nan"] {
            #expect(VoxelImportSettings(query: invalid).framesPerSecond == 30, Comment(rawValue: invalid))
        }
        #expect(VoxelImportSettings(query: "scene=2&unknown=1") == VoxelImportSettings())
    }

    @Test
    func invalidStoredValuesFallBackToDefaultsInOptions() {
        let broken = VoxelImportSettings(voxelSize: -2, framesPerSecond: .nan)

        #expect(broken.options.voxelSize == 0.1)
        #expect(broken.options.framesPerSecond == 30)
        #expect(broken.assetQuery.isEmpty)
    }

    @Test
    func codableRoundTrip() throws {
        let settings = VoxelImportSettings(voxelSize: 0.2, mergeStatic: true, framesPerSecond: 15)
        let decoded = try JSONDecoder().decode(VoxelImportSettings.self, from: JSONEncoder().encode(settings))

        #expect(decoded == settings)
    }

    @Test
    func sourceAppendsSettingsToVoxPathsOnly() {
        let settings = VoxelImportSettings(voxelSize: 0.05, mergeStatic: true)

        #expect(Model3DSource(source: "@res://castle.vox", voxel: settings).assetPath == "@res://castle.vox#voxelSize=0.05&mergeStatic=1")
        #expect(Model3DSource(source: "@res://castle.VOX", voxel: settings).assetPath == "@res://castle.VOX#voxelSize=0.05&mergeStatic=1")
        // Other formats, default settings and missing settings leave the path alone.
        #expect(Model3DSource(source: "@res://hero.glb", voxel: settings).assetPath == "@res://hero.glb")
        #expect(Model3DSource(source: "@res://castle.vox", voxel: VoxelImportSettings()).assetPath == "@res://castle.vox")
        #expect(Model3DSource(source: "@res://castle.vox").assetPath == "@res://castle.vox")
        #expect(Model3DSource(source: "", voxel: settings).assetPath.isEmpty)
        // A path that already carries a query is not extended.
        #expect(Model3DSource(source: "@res://castle.vox#voxelSize=0.3", voxel: settings).assetPath == "@res://castle.vox#voxelSize=0.3")
    }

    @Test
    func sourcesWithDifferentSettingsAreNotEqual() {
        #expect(Model3DSource(source: "a.vox", voxel: VoxelImportSettings(voxelSize: 0.2)) != Model3DSource(source: "a.vox"))
        #expect(Model3DSource(source: "a.vox") == Model3DSource(source: "a.vox"))
    }

    @Test
    func sourceCodableKeepsVoxelSettingsAndReadsOlderFiles() throws {
        let source = Model3DSource(source: "@res://castle.vox", voxel: VoxelImportSettings(voxelSize: 0.2))
        #expect(try JSONDecoder().decode(Model3DSource.self, from: JSONEncoder().encode(source)) == source)

        // A source saved before the voxel field existed has no "voxel" key.
        let legacy = Data(#"{"source":"@res://castle.vox","animation":"","autoplay":false,"repeats":true}"#.utf8)
        let decoded = try JSONDecoder().decode(Model3DSource.self, from: legacy)
        #expect(decoded.voxel == nil)
        #expect(decoded.source == "@res://castle.vox")
    }
}
