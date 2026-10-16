#if os(iOS) || os(Android)
    @_spi(AdaEngine) import AdaEngine
    import Foundation
    #if DEBUG && !os(Android) && canImport(AdaMCPPlugin)
        import AdaMCPPlugin
    #endif

    struct AdaEditorPhoneApp: App {
        var body: some AppScene {
            WindowGroup(content: {
                MobileEditorRootView()
                    .theme(.adaEditor)
                    .ignoresSafeArea([.horizontal, .bottom])
            }, assetBundle: mobileAssetBundle)
            .windowMode(.windowed)
            .windowTitle("Ada Studio")
            .addPlugins(MobileEditorFramePacingPlugin())
            #if DEBUG && !os(Android) && canImport(AdaMCPPlugin)
                .addPlugins(MCPPlugin(configuration: .init(
                    enableHTTP: CommandLine.arguments.contains { $0.hasPrefix("--mcp-port=") },
                    enableStdio: false,
                    host: EditorMCPServerAddress.host,
                    port: EditorMCPServerAddress.port,
                    endpoint: EditorMCPServerAddress.endpoint,
                    serverName: "Ada Studio Mobile"
                )))
            #endif
        }

        private var mobileAssetBundle: Bundle? {
            #if os(Android)
            .editor
            #else
            nil
            #endif
        }
    }

    private struct MobileEditorFramePacingPlugin: Plugin {
        func setup(in app: borrowing AppWorlds) {
            app.insertResource(ApplicationFramePacing.adaptiveUI())
        }
    }
#endif
