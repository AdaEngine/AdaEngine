@_spi(AdaEngine) import AdaEngine
import AdaScriptCompilerCore
import Foundation

#if os(macOS)
import Darwin
#endif

struct EditorUIExportManifest: Codable, Sendable {
    struct Native: Codable, Sendable {
        var source: String
        var provider: String
        var views: [UIDescriptorSignature]
        var modifiers: [UIDescriptorSignature]
    }
    var version: Int
    var native: [Native]
    var scripts: [AdaScriptUIExport]
}

@MainActor
final class EditorUIExportLoader {
    private var retainedLibraries: [UIExportLibrary] = []
    // Loaded factories and their mounted Views must outlive all calls into the module.
    // Keep handles until process exit, matching EditorPreviewDynamicLibrary's existing ABI.
    private var retainedHandles: [UnsafeMutableRawPointer] = []

    func load(projectURL: URL, packageModel: SwiftPackageModel?, builder: EditorPreviewBuilder) async throws -> UICatalog {
        let manifestURL = projectURL.appendingPathComponent(".ada/ui-exports.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else { return .standard }
        let manifest = try JSONDecoder().decode(EditorUIExportManifest.self, from: Data(contentsOf: manifestURL))
        guard manifest.version == 1 else { throw UIDiagnostic("Unsupported UI export manifest version.") }
        var catalog = UICatalog.standard
        let resources = UISceneResources(rootURL: projectURL)
        for native in manifest.native {
            guard native.provider.range(of: "^[A-Za-z_][A-Za-z0-9_]*(\\.[A-Za-z_][A-Za-z0-9_]*)*$", options: .regularExpression) != nil else {
                throw UIDiagnostic("Invalid Swift UI export provider name.")
            }
            #if os(macOS)
            guard let packageModel else { throw UIDiagnostic("Resolve the SwiftPM project to load '\(native.provider)'.") }
            let source = try resources.resolve(native.source)
            let document = EditorTextDocument(id: "ui-export:\(native.source)", title: source.lastPathComponent, relativePath: native.source,
                                              absolutePath: source.path, language: .swift, content: try String(contentsOf: source, encoding: .utf8), errorMessage: nil)
            var request = EditorPreviewBuildRequest(projectURL: projectURL, document: document, packageModel: packageModel,
                                                   declaration: .init(id: native.provider, title: native.provider, typeName: native.provider, line: 1))
            request.uiExportProvider = native.provider
            let artifact = try await builder.build(request)
            let library = try loadLibrary(artifact)
            guard library.views.map(\.signature).sorted(by: { $0.id < $1.id }) == native.views.sorted(by: { $0.id < $1.id }),
                  library.modifiers.map(\.signature).sorted(by: { $0.id < $1.id }) == native.modifiers.sorted(by: { $0.id < $1.id }) else {
                throw UIDiagnostic("UI export signatures do not match compiled provider '\(native.provider)'.")
            }
            catalog = try catalog.adding(views: library.views, modifiers: library.modifiers)
            #else
            throw UIDiagnostic("Swift UI provider '\(native.provider)' must be compiled into this host.")
            #endif
        }
        for script in manifest.scripts {
            let source = try resources.resolve(script.source)
            catalog = try catalog.adding(script: script, sources: AdaScriptUISource.sources(at: source))
        }
        return catalog
    }

    #if os(macOS)
    private func loadLibrary(_ artifact: EditorPreviewBuildArtifact) throws -> UIExportLibrary {
        guard let handle = dlopen(artifact.libraryURL.path, RTLD_NOW | RTLD_LOCAL) else { throw UIDiagnostic("Could not load UI exports: \(artifact.libraryURL.path)") }
        guard let symbol = dlsym(handle, artifact.symbolName) else { dlclose(handle); throw UIDiagnostic("Missing UI export entry point.") }
        typealias Factory = @convention(c) () -> UnsafeMutableRawPointer
        let factory = unsafeBitCast(symbol, to: Factory.self)
        let library = Unmanaged<UIExportLibrary>.fromOpaque(factory()).takeRetainedValue()
        retainedHandles.append(handle); retainedLibraries.append(library)
        return library
    }
    #endif
}
