import AdaEngine
import Foundation

@main
struct AdaptiveSceneViewExampleApp: App {
    var body: some AppScene {
        WindowGroup { AdaptiveExample() }
            .windowTitle("Foldable Preview · Swift")
            .windowMode(.windowed)
    }
}

private struct AdaptiveExample: View {
    @State private var expanded = false

    var body: some View {
        VStack {
            Button(expanded ? "Compact" : "Expanded") { expanded.toggle() }
            AdaptiveSceneView(layout: .foldable(expanded: expanded), make: { app in
                app.addPlugin(TransformPlugin())
                app.addPlugin(InputPlugin())
                app.addPlugin(RenderWorldPlugin())
                app.addPlugin(CameraPlugin())
                app.addPlugin(VisibilityPlugin())
                app.addPlugin(AssetsPlugin(filePath: #filePath))
                app.addPlugin(SpritePlugin())
                app.addPlugin(Core2DPlugin())
                app.addPlugin(UpscalePlugin())
                if let resources = Bundle.module.resourceURL {
                    let runtime = UIComponentRuntime(resourceRoot: resources.appendingPathComponent("Resources"))
                    app.main.insertResource(UIComponentRuntimeResource(runtime))
                    app.main.spawn("Companion") { CompanionPanel(source: .init(path: "FoldableInfo.ui")) }
                }
                app.main.spawn("Player") {
                    Transform(position: Vector3(0, 0, 1))
                    Sprite(tintColor: Color.fromHex(0x50EACB), size: Size(width: 36, height: 36))
                    Visibility.visible
                }
            }, updateContent: { world, _ in
                // The same API is available to AdaScript through @res DisplayLayout.
                guard let display = world.getResource(DisplayLayout.self) else { return }
                for entity in world.getEntities() {
                    guard var sprite = entity.components[Sprite.self] else { continue }
                    sprite.tintColor = display.isExpanded ? .green : Color.fromHex(0x50EACB)
                    entity.components += sprite
                }
            })
        }
    }
}
