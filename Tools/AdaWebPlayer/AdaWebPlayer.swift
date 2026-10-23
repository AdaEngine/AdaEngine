import AdaEngine
import AdaScriptCompilerCore
import Foundation
#if os(WASI)
import JavaScriptKit
#endif

/// A fixed host: no game source is compiled into this executable or its SwiftPM resources.
@main
struct AdaWebPlayer: App {
    private let project: AdaWebPlayerProject?
    private let sources: [AdaScriptSource]
    private let loadError: String?
    private let directory: URL

    init() {
        #if os(WASI)
        let directory = URL(fileURLWithPath: "/game", isDirectory: true)
        #else
        let directory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "game", isDirectory: true)
        #endif
        self.directory = directory
        do {
            let project = try AdaWebPlayerProject.load(at: directory)
            self.sources = try project.loadSources(at: directory)
            self.project = project
            self.loadError = nil
            print("[AdaWebPlayer] Loaded \(project.title): \(sources.count) external AdaScript sources, runtime API \(project.runtimeAPI)")
        } catch {
            self.project = nil
            self.sources = []
            self.loadError = String(describing: error)
            print("[AdaWebPlayer] Load failed: \(error)")
        }
    }

    var body: some AppScene {
        WindowGroup {
            PlayerContent(project: project, sources: sources, loadError: loadError, directory: directory)
        }
        .windowTitle(project?.title ?? "AdaEngine Web Player")
        .windowMode(.windowed)
    }
}

@MainActor
private struct PlayerContent: View {
    let project: AdaWebPlayerProject?
    let sources: [AdaScriptSource]
    let loadError: String?
    let directory: URL
    @State private var content: AnyView?
    @State private var didLoad = false
    @State private var agentBridge = PlayerAgentBridge()
    #if os(WASI)
    @State private var reloadCallback: JSClosure?
    #endif

    init(project: AdaWebPlayerProject?, sources: [AdaScriptSource], loadError: String?, directory: URL) {
        self.project = project; self.sources = sources; self.loadError = loadError; self.directory = directory
    }

    @discardableResult
    private func load(reload: Bool = false, requestID: String? = nil) -> String? {
        agentBridge.install()
        installReloadCallback()
        guard reload || !didLoad else { return nil }
        didLoad = true
        do {
            let currentProject = reload ? try AdaWebPlayerProject.load(at: directory) : project
            guard let project = currentProject else {
                throw AdaWebPlayerProjectError.invalid(loadError ?? "Missing project.")
            }
            let sources = reload ? try project.loadSources(at: directory) : sources
            if project.entryScene != nil {
                #if os(WASI)
                let frameID = requestID ?? JSObject.global["__adaStudioRequestID"].string
                #else
                let frameID: String? = nil
                #endif
                var presented = false
                let scene = try PlayerScene(project: project, sources: sources, directory: directory, onFrameRendered: { _ in
                    guard !presented else { return }
                    presented = true
                    #if os(WASI)
                    if let frameID, let ready = JSObject.global["__adaStudioFrameReady"].function { _ = ready(frameID) }
                    #endif
                })
                // A new identity tears down the previous world, while retaining the
                // browser window, renderer, GPU device and compiled WASM instance.
                self.content = AnyView(scene.view.id(UUID()))
                agentBridge.runtimeDiagnostics = { scene.script.diagnostics }
                agentBridge.gameInput = scene.gameInput
                print("[AdaWebPlayer] Ready: scene \(project.entryScene ?? "")")
                return nil
            }
            guard try AdaScriptSchemaParser.parse(sources: sources).isEmpty else {
                throw AdaWebPlayerProjectError.invalid("Web Player views do not support native components or resources.")
            }
            guard try AdaScriptSchemaParser.parseSystemCapabilities(sources: sources).isEmpty,
                project.startupSystem == nil else {
                throw AdaWebPlayerProjectError.invalid("AdaScript systems require the scene profile.")
            }
            let resources = PlayerResources(project: project, directory: directory)
            self.content = AnyView(try AdaScriptView(sources: sources, identifier: project.entryView, catalog: resources.catalog()))
            print("[AdaWebPlayer] Ready: \(project.entryView)")
            return nil
        } catch {
            print("[AdaWebPlayer] Startup failed: \(error)")
            if !reload { self.content = AnyView(
                Text("Unable to start game: \(error)")
                    .foregroundColor(.red)
                    .padding(24)
            ) }
            return String(describing: error)
        }
    }

    private func installReloadCallback() {
        #if os(WASI)
        guard reloadCallback == nil, JSObject.global["__adaStudioPreview"].boolean == true else { return }
        let callback = JSClosure { values in
            let requestID = values.first?.string
            let error = MainActor.assumeIsolated { load(reload: true, requestID: requestID) }
            return error.map(JSValue.string) ?? .null
        }
        reloadCallback = callback
        JSObject.global["__adaStudioReload"] = callback.jsValue
        #endif
    }

    var body: some View {
        Group {
            if let content { content }
            else { Text("Loading game…").foregroundColor(.white) }
        }
        // RenderEngine's default textures are installed after the window exists.
        // Scene assets must not be constructed while WindowGroup is still being described.
        .task { _ = await load() }
    }
}
