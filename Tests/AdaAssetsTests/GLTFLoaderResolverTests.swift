@testable import AdaAssets
import Foundation
import Testing

@Suite
struct GLTFLoaderResolverTests {
    private var modelURL: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/TwoBoneRibbon.glb")
    }

    @Test("GLB import works before Core3DPlugin or a render host is initialized")
    func loadsWithNativeDefault() async throws {
        let resolver = GLTFLoaderResolver()
        let result = try await resolver.getLoader().load(url: modelURL)
        #expect(!result.meshes.isEmpty)
        #expect(result.skins.count == 1)
        #expect(result.animations.map(\.name) == ["Bend"])
    }

    @Test("Explicit custom loaders and in-flight loader snapshots remain supported")
    func preservesCustomLoaderSnapshot() async throws {
        let resolver = GLTFLoaderResolver()
        resolver.setLoader(ProbeLoader())
        let snapshot = resolver.getLoader()
        resolver.setLoader(NativeGLTFLoader())
        await #expect(throws: ProbeError.selected) {
            try await snapshot.load(url: modelURL)
        }
        let imported = try await resolver.getLoader().load(url: modelURL)
        #expect(imported.skins.count == 1)
    }

    @Test("Concurrent selection and imports use valid Sendable snapshots")
    func concurrentSelectionAndImports() async throws {
        let resolver = GLTFLoaderResolver()
        let url = modelURL
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                for _ in 0..<128 { resolver.setLoader(NativeGLTFLoader()) }
            }
            for _ in 0..<16 {
                group.addTask {
                    let imported = try await resolver.getLoader().load(url: url)
                    #expect(imported.skins.count == 1)
                    #expect(imported.animations.map(\.name) == ["Bend"])
                }
            }
            try await group.waitForAll()
        }
    }
}

private enum ProbeError: Error, Equatable {
    case selected
}

private struct ProbeLoader: GLTFLoader {
    func load(url _: URL) async throws -> GLTFImportResult {
        throw ProbeError.selected
    }
}
