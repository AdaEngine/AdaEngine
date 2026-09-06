@testable import AdaEditor
import Foundation
import Testing

@Suite("Editor inspector")
struct EditorInspectorTests {
    @Test("component picker searches names, categories, and descriptions")
    @MainActor
    func componentPickerSearchesCatalogMetadata() {
        let viewModel = EditorInspectorSidebarViewModel()
        viewModel.selectEntity(
            EditorInspectorSidebarViewModel.SelectedEntity(
                editorID: "entity-1",
                name: "Player",
                componentNames: [],
                transformFields: [],
                components: [],
                addableComponents: [
                    .init(typeName: "Camera", displayName: "Camera", category: "Rendering", description: "Renders the scene."),
                    .init(typeName: "Light2D", displayName: "Light 2D", category: "2D", description: "Casts shadows.")
                ],
                gizmo: nil,
                hasExplicitGizmo: false
            )
        )

        #expect(viewModel.addableComponents(matching: "render").map(\.typeName) == ["Camera"])
        #expect(viewModel.addableComponents(matching: "shadow").map(\.typeName) == ["Light2D"])
        #expect(viewModel.addableComponents(matching: "2d").map(\.typeName) == ["Light2D"])
    }

    @Test("color values round trip RGBA and hex")
    func colorValuesRoundTrip() throws {
        let value = try #require(EditorInspectorColorValue(rgbaText: "1, 0.5, 0, 0.25"))
        #expect(value.hexString == "#FF800040")

        let decoded = try #require(EditorInspectorColorValue(hexText: value.hexString))
        #expect(abs(decoded.red - 1) < 0.001)
        #expect(abs(decoded.green - Float(128) / 255) < 0.001)
        #expect(abs(decoded.blue) < 0.001)
        #expect(abs(decoded.alpha - Float(64) / 255) < 0.001)
    }

    @Test("texture picker filters project assets and resolves dropped files")
    @MainActor
    func texturePickerResolvesDroppedProjectAsset() {
        let viewModel = EditorInspectorSidebarViewModel()
        viewModel.textureAssets = [
            .init(name: "player.png", reference: "@res://Textures/player.png", absolutePath: "/tmp/Game/Assets/Textures/player.png"),
            .init(name: "sky.png", reference: "@res://Backgrounds/sky.png", absolutePath: "/tmp/Game/Assets/Backgrounds/sky.png")
        ]

        #expect(viewModel.textureAssets(matching: "player").map(\.reference) == ["@res://Textures/player.png"])
        #expect(viewModel.textureAsset(droppedFileURL: URL(fileURLWithPath: "/tmp/Game/Assets/Textures/player.png"))?.name == "player.png")
        #expect(viewModel.textureAsset(droppedFileURL: URL(fileURLWithPath: "/tmp/outside.png")) == nil)
    }

    @Test("sprite texture and size fields are editable")
    func spriteTextureAndSizeFieldsAreEditable() throws {
        let descriptor = try #require(EditorComponentRegistry.descriptor(named: EditorBuiltInComponentType.sprite))
        #expect(descriptor.fields.first { $0.key == "texture" }?.isEditable == true)
        #expect(descriptor.fields.first { $0.key == "size" }?.isEditable == true)
        #expect(!descriptor.description.isEmpty)
    }
}
