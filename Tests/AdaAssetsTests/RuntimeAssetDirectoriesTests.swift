import Foundation
import Testing

@testable import AdaAssets

@Suite("Runtime asset directories")
struct RuntimeAssetDirectoriesTests {
    @Test("release asset directories follow relocated bundle resources")
    func relocatedResources() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = root.appendingPathComponent("Game.app/Contents/Resources")
        try FileManager.default.createDirectory(at: original.appendingPathComponent("Assets"), withIntermediateDirectories: true)
        let moved = root.appendingPathComponent("Moved Resources")
        try FileManager.default.moveItem(at: original, to: moved)
        let directories = AssetsManager.runtimeProjectDirectories(resourceURL: moved)
        #expect(directories.source == moved)
        #expect(directories.assetsDirectory == moved.appendingPathComponent("Assets"))
        #expect(!FileManager.default.fileExists(atPath: original.path))
    }

    @Test("resource discovery never creates directories at a missing location")
    func missingResourcesDoNotCreateDirectories() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let directories = AssetsManager.runtimeProjectDirectories(resourceURL: root)
        #expect(directories.assetsDirectory == root)
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }
}
