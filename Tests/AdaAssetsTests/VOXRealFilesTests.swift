import AdaAssets
import Foundation
import Testing

/// Parses real MagicaVoxel files. Set `ADAENGINE_VOX_SAMPLES` to a directory with `.vox` files, for example the
/// `vox` folder of a MagicaVoxel release; the files are not part of the repository.
@Suite
struct VOXRealFilesTests {
    private static let samplesPath = ProcessInfo.processInfo.environment["ADAENGINE_VOX_SAMPLES"]

    private static func files() -> [URL] {
        guard let samplesPath,
            let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: samplesPath), includingPropertiesForKeys: nil)
        else {
            return []
        }
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension.lowercased() == "vox" }.sorted { $0.path < $1.path }
    }

    @Test(.enabled(if: samplesPath != nil))
    func parsesEverySample() async throws {
        let samples = Self.files()
        try #require(!samples.isEmpty, "ADAENGINE_VOX_SAMPLES contains no .vox files")

        for url in samples {
            let file = try await VOXLoader().load(url: url)
            let name = url.lastPathComponent
            let voxels = file.models.reduce(0) { $0 + $1.voxels.count }
            print("VOXSAMPLE \(name): version \(file.version), models \(file.models.count), voxels \(voxels), nodes \(file.nodes.count), layers \(file.layers.count), materials \(file.materials.count), customPalette \(file.hasCustomPalette)")

            #expect(!file.models.isEmpty, Comment(rawValue: name))
            #expect(voxels > 0, Comment(rawValue: name))
            #expect(file.palette.colors.count == 256, Comment(rawValue: name))
            for model in file.models {
                #expect(model.voxels.allSatisfy { Int($0.x) < model.sizeX && Int($0.y) < model.sizeY && Int($0.z) < model.sizeZ })
            }
            // Every node reference must point at an existing node or model.
            for node in file.nodes.values {
                switch node {
                case .transform(let transform):
                    #expect(file.nodes[transform.childID] != nil, Comment(rawValue: "\(name): nTRN \(transform.id) child"))
                case .group(let group):
                    #expect(group.childIDs.allSatisfy { file.nodes[$0] != nil }, Comment(rawValue: "\(name): nGRP \(group.id) children"))
                case .shape(let shape):
                    #expect(shape.models.allSatisfy { file.models.indices.contains($0.modelIndex) }, Comment(rawValue: "\(name): nSHP \(shape.id) models"))
                }
            }
            if version2Scene(file) {
                #expect(file.rootNode != nil, Comment(rawValue: "\(name): scene graph without a root"))
            }
        }
    }

    private func version2Scene(_ file: VOXFile) -> Bool {
        !file.nodes.isEmpty
    }
}
