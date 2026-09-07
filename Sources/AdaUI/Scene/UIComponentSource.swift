import AdaECS
import AdaRender
import AdaUIDescription
import AdaUtils
import Foundation

/// Serializable source of an ECS UI. Native closures and live View instances are never encoded.
public struct UIComponentSource: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable { case ui, script, swiftView }
    public var kind: Kind
    public var path: String
    public var identifier: String
    public var contextName: String
    public var inputs: [String: UIValue]

    public init(kind: Kind = .ui, path: String = "", identifier: String = "", contextName: String = "", inputs: [String: UIValue] = [:]) {
        self.kind = kind; self.path = path; self.identifier = identifier; self.contextName = contextName; self.inputs = inputs
    }
}

/// Runtime services are scoped to a world/project, so concurrently open projects never share UI state.
@MainActor
public final class UIComponentRuntime {
    public var catalog: UICatalog
    public let resources: UISceneResources
    public var defaultContext: UIBindingContext?
    public var contexts: [String: UIBindingContext] = [:]
    public var scriptFactory: (@MainActor (UIComponentSource, UIBindingContext, UISceneResources) throws -> AnyView)?
    private var sessions: [WeakUISession] = []

    public init(resourceRoot: URL, catalog: UICatalog = .standard) {
        self.resources = UISceneResources(rootURL: resourceRoot)
        self.catalog = catalog
    }

    public func makeView(source: UIComponentSource) throws -> AnyView {
        let context: UIBindingContext
        if source.contextName.isEmpty { context = defaultContext ?? UIBindingContext(values: source.inputs) }
        else if let named = contexts[source.contextName] { context = named }
        else { throw UIDiagnostic("Unknown UI context '\(source.contextName)'.") }
        switch source.kind {
        case .ui:
            let url = try resources.resolve(source.path)
            let session = try UISceneSession(document: resources.load(url), context: context, catalog: catalog, resources: resources, sourceURL: url)
            sessions.append(WeakUISession(session))
            return AnyView(UISceneView(session: session))
        case .script:
            guard let scriptFactory else { throw UIDiagnostic("This host has no AdaScript UI source provider.") }
            return try scriptFactory(source, context, resources)
        case .swiftView:
            let node = UINodeDescription(type: source.identifier, arguments: source.inputs.mapValues { .init(value: $0) })
            return AnyView(UISceneView(session: try UISceneSession(document: .init(root: node), context: context, catalog: catalog, resources: resources)))
        }
    }

    /// Revalidates mounted scenes after a file watcher reports a resource change.
    public func reload(_ url: URL, document: UISceneDocument? = nil) throws {
        if let document { try resources.publish(document, at: url) } else { resources.invalidate(url) }
        sessions.removeAll { $0.value == nil }
        for session in sessions.compactMap(\.value) {
            let candidate = try session.sourceURL.map(resources.load) ?? session.document
            _ = session.update(candidate)
            session.context.invalidate()
        }
    }
}

private final class WeakUISession {
    weak var value: UISceneSession?
    init(_ value: UISceneSession) { self.value = value }
}

/// Insert into a world's resources before loading entities with file-backed UI components.
public struct UIComponentRuntimeResource: Resource {
    public let runtime: UIComponentRuntime
    public init(_ runtime: UIComponentRuntime) { self.runtime = runtime }
}

final class UIComponentStorage: Sendable {
    let source: UIComponentSource?
    let suppliedView: UIView?
    @MainActor private var resolvedView: UIView?
    @MainActor private var runtime: UIComponentRuntime?

    init(view: UIView) { suppliedView = view; source = nil }
    init(source: UIComponentSource) { suppliedView = nil; self.source = source }

    @MainActor
    func resolve(runtime: UIComponentRuntime?) throws -> UIView {
        if let suppliedView { return suppliedView }
        if let resolvedView { return resolvedView }
        guard let source else { throw UIDiagnostic("Missing UI source.") }
        let runtime = runtime ?? self.runtime ?? UIComponentRuntime(resourceRoot: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        self.runtime = runtime
        let view = UIContainerView(rootView: try runtime.makeView(source: source))
        view.backgroundColor = .clear
        resolvedView = view
        return view
    }
}
