import AdaEngine
import Testing

@testable import AdaEditorKit

@MainActor
private final class TestExtension: EditorExtension {
    var manifest: EditorExtensionManifest
    var contributions: [any EditorContribution]
    var shouldFail = false
    private(set) var deactivateCount = 0

    init(manifest: EditorExtensionManifest, contributions: [any EditorContribution]) {
        self.manifest = manifest
        self.contributions = contributions
    }

    func activate(in context: EditorExtensionContext) throws {
        for contribution in contributions {
            context.register(contribution)
        }
        if shouldFail {
            throw EditorExtensionError.duplicateExtension("forced")
        }
    }

    func deactivate() { deactivateCount += 1 }
}

private func panel(_ id: String) -> PanelContribution {
    PanelContribution(id: id, title: id) { AnyView(EmptyView()) }
}

private func terrainEditor(_ id: String = "terrain.editor") -> DocumentEditorContribution {
    DocumentEditorContribution(id: id, title: "Terrain", fileExtensions: ["Terrain"]) { _ in AnyView(EmptyView()) }
}

@Suite("Editor extension registry")
@MainActor
struct EditorExtensionRegistryTests {
    @Test func activationRegistersAndDeactivationRemovesEverything() throws {
        let registry = EditorExtensionRegistry(platform: .macOS)
        let manifest = EditorExtensionManifest(id: "terrain", name: "Terrain", permissions: [.documentsRead])
        let terrain = TestExtension(manifest: manifest, contributions: [panel("terrain.panel"), terrainEditor()])

        try registry.activate(terrain)
        #expect(registry.panels.map(\.id) == ["terrain.panel"])
        #expect(registry.documentEditor(forFileExtension: "TERRAIN")?.id == "terrain.editor")
        #expect(registry.activeExtensionIDs == ["terrain"])

        registry.deactivate(extensionID: "terrain")
        #expect(registry.panels.isEmpty)
        #expect(registry.documentEditors.isEmpty)
        #expect(terrain.deactivateCount == 1)
        #expect(registry.activeExtensionIDs.isEmpty)
    }

    @Test func failedActivationRegistersNothing() {
        let registry = EditorExtensionRegistry(platform: .macOS)
        let terrain = TestExtension(manifest: EditorExtensionManifest(id: "terrain", name: "Terrain"), contributions: [panel("a")])
        terrain.shouldFail = true

        #expect(throws: EditorExtensionError.self) { try registry.activate(terrain) }
        #expect(registry.panels.isEmpty)
        #expect(registry.activeExtensionIDs.isEmpty)
    }

    @Test func duplicateContributionIDIsRejectedAcrossExtensions() throws {
        let registry = EditorExtensionRegistry(platform: .macOS)
        let first = TestExtension(manifest: EditorExtensionManifest(id: "one", name: "One"), contributions: [panel("shared")])
        let second = TestExtension(manifest: EditorExtensionManifest(id: "two", name: "Two"), contributions: [panel("other"), panel("shared")])
        try registry.activate(first)

        #expect(
            throws: EditorExtensionError.duplicateContribution(id: "shared", owner: "two", existingOwner: "one")
        ) { try registry.activate(second) }
        #expect(registry.panels.map(\.id) == ["shared"])
        #expect(second.deactivateCount == 1)
    }

    @Test func duplicateIDInsideOneExtensionIsRejected() {
        let registry = EditorExtensionRegistry(platform: .macOS)
        let bad = TestExtension(manifest: EditorExtensionManifest(id: "bad", name: "Bad"), contributions: [panel("x"), panel("x")])

        #expect(throws: EditorExtensionError.duplicateContribution(id: "x", owner: "bad", existingOwner: "bad")) {
            try registry.activate(bad)
        }
        #expect(registry.panels.isEmpty)
    }

    @Test func undeclaredPermissionIsRejected() {
        let registry = EditorExtensionRegistry(platform: .macOS)
        let terrain = TestExtension(manifest: EditorExtensionManifest(id: "terrain", name: "Terrain"), contributions: [terrainEditor()])

        #expect(
            throws: EditorExtensionError.missingPermission(
                extensionID: "terrain",
                contributionID: "terrain.editor",
                permission: .documentsRead
            )
        ) { try registry.activate(terrain) }
        #expect(registry.documentEditors.isEmpty)
    }

    @Test func newerAPIVersionAndWrongPlatformAreRefused() {
        let registry = EditorExtensionRegistry(platform: .iOS)
        let future = TestExtension(
            manifest: EditorExtensionManifest(id: "future", name: "Future", apiVersion: EditorExtensionManifest.currentAPIVersion + 1),
            contributions: []
        )
        let desktop = TestExtension(
            manifest: EditorExtensionManifest(id: "desktop", name: "Desktop", platforms: [.macOS, .windows]),
            contributions: []
        )

        #expect(throws: EditorExtensionError.self) { try registry.activate(future) }
        #expect(throws: EditorExtensionError.unsupportedPlatform(extensionID: "desktop", platform: .iOS)) {
            try registry.activate(desktop)
        }
        #expect(registry.activeExtensionIDs.isEmpty)
    }

    @Test func activatingTheSameExtensionTwiceFails() throws {
        let registry = EditorExtensionRegistry(platform: .windows)
        let terrain = TestExtension(manifest: EditorExtensionManifest(id: "terrain", name: "Terrain"), contributions: [panel("p")])
        try registry.activate(terrain)

        #expect(throws: EditorExtensionError.duplicateExtension("terrain")) { try registry.activate(terrain) }
        #expect(registry.panels.count == 1)
    }
}
