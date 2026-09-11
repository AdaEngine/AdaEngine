import AdaEngine
import Foundation

/// All game registration and resource loading belongs to this project.
@MainActor
public enum FoldProject {
    public static var resources: URL { Bundle.module.bundleURL.appendingPathComponent("Assets") }

    public static func configure(_ app: inout AppWorlds) {
        app.addPlugin(TransformPlugin())
        app.addPlugin(InputPlugin())
        app.addPlugin(RenderWorldPlugin())
        app.addPlugin(CameraPlugin())
        app.addPlugin(AssetsPlugin(filePath: #filePath))
        app.addPlugin(VisibilityPlugin())
        app.addPlugin(Mesh2DPlugin())
        app.addPlugin(Core2DPlugin())
        app.addPlugin(Light2DPlugin())
        app.addPlugin(UpscalePlugin())
        app.addPlugin(ScriptableObjectPlugin())
        app.addPlugin(FoldContentPlugin())
    }

    static func installScripts(in app: AppWorlds) {
        if ScriptableObjectRegistry.descriptor(named: "shadowfold.director") == nil {
            AdaScriptPluginsGenerated().setup(in: app)
        }
    }

    /// Loads the project's authored scene using the components' Codable contracts.
    /// No Editor module or editor-specific component decoder is involved.
    public static func load(into world: World, resources: URL) throws {
        let runtime = UIComponentRuntime(resourceRoot: resources)
        let url = resources.appendingPathComponent("Scenes/Main.ascn")
        let scene = try JSONDecoder().decode(FoldScene.self, from: Data(contentsOf: url))
        guard scene.format == "ada.scene", scene.schemaVersion == 1 else {
            throw UIDiagnostic("Unsupported Fold scene format in \(url.lastPathComponent).")
        }
        // Decode and validate before spawning, so a bad file cannot leave half a scene.
        for entity in scene.entities {
            if let panel = entity.components.panel, let source = panel.ui.source {
                try runtime.validateScriptBindings(source: source)
            }
        }
        world.insertResource(UIComponentRuntimeResource(runtime))
        for item in scene.entities {
            let entity = world.spawn(item.name)
            entity.isActive = item.enabled
            if let value = item.components.level { world.insert(value, for: entity.id) }
            if let value = item.components.attachment { world.insert(value, for: entity.id) }
            if let value = item.components.transfer { world.insert(value, for: entity.id) }
            if let value = item.components.scripts { world.insert(value, for: entity.id) }
            if let value = item.components.panel { world.insert(value, for: entity.id) }
        }
    }
}

private struct FoldScene: Decodable {
    var format: String
    var schemaVersion: Int
    var entities: [SceneEntity]

    struct SceneEntity: Decodable {
        var name: String
        var enabled: Bool
        var components: Components
    }
    struct Components: Decodable {
        var level: ShadowLevel?
        var attachment: FoldAttachment?
        var transfer: ShadowTransferItem?
        var scripts: ScriptableComponents?
        var panel: CompanionPanel?
        enum CodingKeys: String, CodingKey {
            case level = "FoldGame.ShadowLevel"
            case attachment = "FoldGame.FoldAttachment"
            case transfer = "FoldGame.ShadowTransferItem"
            case scripts = "AdaScene.ScriptableComponents"
            case panel = "AdaUI.CompanionPanel"
        }
    }
}

private struct FoldContentPlugin: Plugin {
    @MainActor func setup(in app: AppWorlds) {
        FoldProject.installScripts(in: app)
        do { try FoldProject.load(into: app.main, resources: FoldProject.resources) }
        catch {
            var runtime = ShadowRuntime()
            runtime.error = "Fold scene: \(error.localizedDescription)"
            app.main.insertResource(runtime)
        }
    }
}
