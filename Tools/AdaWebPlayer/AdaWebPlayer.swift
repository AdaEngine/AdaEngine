import AdaEngine
import AdaScriptCompilerCore
import Foundation

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
    private let content: AnyView

    init(project: AdaWebPlayerProject?, sources: [AdaScriptSource], loadError: String?, directory: URL) {
        do {
            guard let project else {
                throw AdaWebPlayerProjectError.invalid(loadError ?? "Missing project.")
            }
            // Reject native data layouts just as the iPad project builder does.
            guard try AdaScriptSchemaParser.parse(sources: sources).isEmpty else {
                throw AdaWebPlayerProjectError.invalid("Web Player does not support custom native components or resources yet.")
            }
            // The prototype deliberately renders a source-backed view. ECS/scene hosting is a subsequent profile.
            guard try AdaScriptSchemaParser.parseSystemCapabilities(sources: sources).isEmpty,
                  project.startupSystem == nil else {
                throw AdaWebPlayerProjectError.invalid("This Web Player profile supports AdaScript views; ECS systems require the scene profile.")
            }
            let resources = PlayerResources(project: project, directory: directory)
            self.content = AnyView(try AdaScriptView(sources: sources, identifier: project.entryView, catalog: resources.catalog()))
            print("[AdaWebPlayer] Ready: \(project.entryView)")
        } catch {
            print("[AdaWebPlayer] Startup failed: \(error)")
            self.content = AnyView(
                Text("Unable to start game: \(error)")
                    .foregroundColor(.red)
                    .padding(24)
            )
        }
    }

    var body: some View { content }
}
