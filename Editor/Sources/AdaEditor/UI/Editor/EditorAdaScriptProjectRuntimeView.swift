@_spi(AdaEngine) import AdaEngine

enum EditorAdaScriptRuntimeError: Error, LocalizedError {
    case windowManagerUnavailable

    var errorDescription: String? {
        switch self {
        case .windowManagerUnavailable:
            "AdaScript runtime cannot create a window because the window manager is unavailable."
        }
    }
}

@MainActor
struct EditorAdaScriptProjectRuntimeView: View {
    private let artifact: EditorAdaScriptProjectBuildArtifact
    private let entryView: AdaScriptView
    private let scriptPlugin: AdaScriptPlugin?

    init(artifact: EditorAdaScriptProjectBuildArtifact) throws {
        self.artifact = artifact
        self.entryView = try AdaScriptView(
            sources: artifact.sources,
            identifier: artifact.entryView
        )
        self.scriptPlugin = artifact.report.systemCount == 0
            ? nil
            : try AdaScriptPlugin(sources: artifact.sources, name: artifact.moduleName)
    }

    var body: some View {
        ZStack {
            SceneView(
                make: { app in
                    configureRuntime(&app)
                },
                updateContent: { _, _ in }
            )
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)

            entryView
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        }
        .background(.black)
    }

    private func configureRuntime(_ app: inout AppWorlds) {
        app.addPlugin(TransformPlugin())
        app.addPlugin(InputPlugin())
        app.addPlugin(RenderWorldPlugin())
        app.addPlugin(EventsPlugin())
        app.addPlugin(CameraPlugin())
        app.addPlugin(AssetsPlugin(assetDirectory: artifact.assetsDirectory))
        app.addPlugin(VisibilityPlugin())
        app.addPlugin(SpritePlugin())
        app.addPlugin(Mesh2DPlugin())
        app.addPlugin(TextPlugin())
        app.addPlugin(ScenePlugin())
        app.addPlugin(ScriptableObjectPlugin())
        app.addPlugin(AudioPlugin())
        app.addPlugin(Physics2DPlugin())
        app.addPlugin(TileMapPlugin())
        app.addPlugin(Core2DPlugin())
        app.addPlugin(Core3DPlugin())
        app.addPlugin(Light2DPlugin())
        app.addPlugin(UpscalePlugin())
        if let scriptPlugin {
            app.addPlugin(scriptPlugin)
        }
    }
}
