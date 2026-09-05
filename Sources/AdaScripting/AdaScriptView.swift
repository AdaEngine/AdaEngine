@_spi(Scripting) import AdaECS
import AdaScriptCompilerCore
import AdaUI
import AdaUtils
import Foundation
import Gravity

/// Metadata for an AdaUI view declared with `@view` in Ada Script.
public struct AdaScriptViewMetadata: Equatable, Sendable {
    public let className: String
    public let environment: [AdaScriptViewEnvironment]
    public let identifier: String
    public let isPreviewable: Bool
    public let line: Int
    public let sourcePath: String
    public let title: String

    public init(
        className: String,
        environment: [AdaScriptViewEnvironment] = [],
        identifier: String,
        isPreviewable: Bool = false,
        line: Int = 1,
        sourcePath: String = "",
        title: String
    ) {
        self.className = className
        self.environment = environment
        self.identifier = identifier
        self.isPreviewable = isPreviewable
        self.line = line
        self.sourcePath = sourcePath
        self.title = title
    }
}

public struct AdaScriptViewEnvironment: Equatable, Sendable {
    public let key: String
    public let propertyName: String

    public init(key: String, propertyName: String) {
        self.key = key
        self.propertyName = propertyName
    }
}

/// Finds `@view` declarations without executing their source.
public enum AdaScriptViewScanner {
    public static func declarations(in sources: [AdaScriptSource]) throws -> [AdaScriptViewMetadata] {
        try AdaScriptSchemaParser.parseViews(sources: sources).map {
            AdaScriptViewMetadata(
                className: $0.className,
                environment: $0.environment.map { AdaScriptViewEnvironment(key: $0.key, propertyName: $0.propertyName) },
                identifier: $0.id,
                isPreviewable: $0.isPreviewable,
                line: $0.line,
                sourcePath: $0.sourcePath,
                title: $0.title
            )
        }
    }
}

/// A native AdaUI view whose declarative tree is supplied by Ada Script.
@MainActor
public struct AdaScriptView: View {
    private let directStorage: AdaScriptViewStorage?
    private let identifier: String
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.scaleFactor) private var scaleFactor
    @Environment(\.userInterfaceIdiom) private var userInterfaceIdiom
    @State private var revision = 0
    @State private var storage: AdaScriptViewStorage?

    /// Creates a view registered by `AdaScriptBuildPlugin`.
    public init(_ identifier: String) {
        self.directStorage = nil
        self.identifier = identifier
    }

    /// Creates a view directly from source, primarily for tools and previews.
    public init(sources: [AdaScriptSource], identifier: String) throws {
        let metadata = try AdaScriptViewScanner.declarations(in: sources)
        let runtime = try AdaScriptViewModuleRuntime(sources: sources, views: metadata)
        let storage = try runtime.makeStorage(identifier: identifier)
        try storage.updateEnvironment(defaultAdaScriptViewEnvironment())
        self.directStorage = storage
        self.identifier = identifier
    }

    /// Compiles and validates a source-backed view without constructing UI state.
    ///
    /// Editor build tooling uses this entry point away from the main actor before
    /// publishing a prepared runtime artifact back to the UI.
    nonisolated public static func validate(
        sources: [AdaScriptSource],
        identifier: String
    ) throws {
        try AdaScriptRuntimeCoordinator.lock.withLock {
            let metadata = try AdaScriptViewScanner.declarations(in: sources)
            let runtime = try AdaScriptViewModuleRuntime(sources: sources, views: metadata)
            try runtime.validate(identifier: identifier)
        }
    }

    public var body: some View {
        _ = revision
        do {
            let resolvedStorage: AdaScriptViewStorage
            if let storage {
                resolvedStorage = storage
            } else if let directStorage {
                storage = directStorage
                resolvedStorage = directStorage
            } else {
                let newStorage = try AdaScriptViewRegistry.makeStorage(identifier: identifier)
                storage = newStorage
                resolvedStorage = newStorage
            }
            try resolvedStorage.updateEnvironment([
                "colorScheme": .string(colorScheme == .dark ? "dark" : "light"),
                "isEnabled": .bool(isEnabled),
                "scaleFactor": .double(Double(scaleFactor)),
                "userInterfaceIdiom": .string(userInterfaceIdiom.adaScriptName)
            ])
            if let error = resolvedStorage.error {
                return AnyView(
                    Text("Ada Script view error: \(error)")
                        .foregroundColor(.red)
                        .padding(12)
                )
            }
            let revision = $revision
            guard let model = resolvedStorage.model else {
                throw AdaScriptError.invalidManifest("@view '\(identifier)' did not produce a view tree")
            }
            return AnyView(
                AdaScriptRenderedView(
                    model: model,
                    performAction: { action in
                        do {
                            try resolvedStorage.perform(action: action)
                        } catch {
                            resolvedStorage.error = error
                        }
                        revision.wrappedValue += 1
                    }
                )
            )
        } catch {
            return AnyView(
                Text("Ada Script view error: \(error)")
                    .foregroundColor(.red)
                    .padding(12)
            )
        }
    }
}

/// Process-wide registry populated by generated Ada Script plugins.
@MainActor
public enum AdaScriptViewRegistry {
    private struct Registration {
        let moduleName: String
        let runtime: AdaScriptViewModuleRuntime
    }

    private static var registrations: [String: Registration] = [:]

    public static func register(
        views: [AdaScriptViewMetadata],
        sources: [AdaScriptSource],
        moduleName: String
    ) throws {
        guard !views.isEmpty else {
            return
        }

        let runtime = try AdaScriptViewModuleRuntime(sources: sources, views: views)
        for view in views {
            let storage = try runtime.makeStorage(identifier: view.identifier)
            try storage.updateEnvironment(defaultAdaScriptViewEnvironment())
        }

        var next = registrations.filter { $0.value.moduleName != moduleName }
        for view in views {
            guard next[view.identifier] == nil else {
                throw AdaScriptError.invalidManifest("Duplicate @view id '\(view.identifier)'")
            }
            next[view.identifier] = Registration(moduleName: moduleName, runtime: runtime)
        }
        registrations = next
    }

    public static func makeView(identifier: String) throws -> AnyView {
        let storage = try makeStorage(identifier: identifier)
        try storage.updateEnvironment(defaultAdaScriptViewEnvironment())
        guard let model = storage.model else {
            throw AdaScriptError.invalidManifest("@view '\(identifier)' did not produce a view tree")
        }
        return AnyView(
            AdaScriptRenderedView(
                model: model,
                performAction: { action in try? storage.perform(action: action) }
            )
        )
    }

    static func makeStorage(identifier: String) throws -> AdaScriptViewStorage {
        guard let registration = registrations[identifier] else {
            throw AdaScriptError.invalidManifest("Unknown @view id '\(identifier)'")
        }
        return try registration.runtime.makeStorage(identifier: identifier)
    }
}

final class AdaScriptViewModuleRuntime: @unchecked Sendable {
    private let factoryNamesByIdentifier: [String: String]
    private let viewsByIdentifier: [String: AdaScriptViewMetadata]
    // The runtime owns its delegate for exactly the VM lifetime; this is not a callback back-reference.
    // swiftlint:disable:next weak_delegate
    private let delegate: AnnotatedGravityRuntimeDelegate
    private let virtualMachine: GravityVirtualMachine

    init(sources: [AdaScriptSource], views: [AdaScriptViewMetadata]) throws {
        let module = try GravityScriptModuleResolver.resolve(sources)
        self.factoryNamesByIdentifier = Dictionary(uniqueKeysWithValues: views.enumerated().map { index, view in
            (view.identifier, "__ada_make_view_\(index)")
        })
        self.viewsByIdentifier = Dictionary(uniqueKeysWithValues: views.map { ($0.identifier, $0) })

        let delegate = AnnotatedGravityRuntimeDelegate(module: module)
        self.delegate = delegate

        self.virtualMachine = try AdaScriptRuntimeCoordinator.lock.withLock {
            let virtualMachine = GravityVirtualMachine(settings: .init(), delegate: delegate)
            try virtualMachine.bindClass(with: AdaScriptViewBridge.self)
            virtualMachine.setValue(AdaScriptViewBridge(), forKey: "adaUIBuilder")

            let factories = views.enumerated()
                .map { index, view in
                    "func __ada_make_view_\(index)() { return \(view.className)(); }"
                }
                .joined(separator: "\n")
            let binary = virtualMachine.loadGravityFile(from: module.entrySource + "\n" + factories)
            guard delegate.errors.isEmpty else {
                throw AdaScriptError.compilation(delegate.errors)
            }
            virtualMachine.load(binary)
            guard delegate.errors.isEmpty else {
                throw AdaScriptError.compilation(delegate.errors)
            }
            return virtualMachine
        }
    }

    @MainActor
    func makeStorage(identifier: String) throws -> AdaScriptViewStorage {
        try AdaScriptViewStorage(runtime: self, identifier: identifier)
    }

    func validate(identifier: String) throws {
        _ = try makeInstance(identifier: identifier)
    }

    @MainActor
    func instantiate(identifier: String) throws -> GSValue {
        try makeInstance(identifier: identifier)
    }

    private func makeInstance(identifier: String) throws -> GSValue {
        try AdaScriptRuntimeCoordinator.lock.withLock {
            guard let factoryName = factoryNamesByIdentifier[identifier] else {
                throw AdaScriptError.invalidManifest("Unknown @view id '\(identifier)'")
            }
            let factory = virtualMachine.getValue(forKey: factoryName)
            guard factory.isClosure,
                  let instance = factory.callConstructor(with: []),
                  instance.isInstance else {
                throw AdaScriptError.invalidManifest("Unable to instantiate @view '\(identifier)'")
            }
            guard instance.hasMethod(named: "body") else {
                throw AdaScriptError.invalidManifest("@view '\(identifier)' must define body()")
            }
            return instance
        }
    }

    @MainActor
    func evaluate(
        instance: GSValue,
        identifier: String,
        environment: [String: EditorFieldValue]
    ) throws -> AdaScriptViewModel {
        try AdaScriptRuntimeCoordinator.lock.withLock {
            guard let metadata = viewsByIdentifier[identifier] else {
                throw AdaScriptError.invalidManifest("Unknown @view id '\(identifier)'")
            }
            for binding in metadata.environment {
                guard let value = environment[binding.key] else {
                    throw AdaScriptError.invalidManifest("Unknown environment key '\(binding.key)' in @view '\(identifier)'")
                }
                guard instance.setStoredProperty(
                    named: binding.propertyName,
                    to: AnnotatedGravityValueBridge.makeGravityValue(value, virtualMachine: virtualMachine)
                ) else {
                    throw AdaScriptError.invalidManifest("Unable to bind @environment property '\(binding.propertyName)' in @view '\(identifier)'")
                }
            }
            let builder = AdaScriptViewBridge()
            virtualMachine.setValue(builder, forKey: "adaUIBuilder")
            guard let value = instance.callMethod(named: "body", with: []),
                  let bridge = value.toObjectOf(AdaScriptViewBridge.self) else {
                let diagnostic = delegate.errors.last.map { ": \($0)" } ?? ""
                throw AdaScriptError.invalidManifest("@view '\(identifier)' body() must return a View value\(diagnostic)")
            }
            return bridge.model
        }
    }

    @MainActor
    func perform(instance: GSValue, action: String, identifier: String) throws {
        try AdaScriptRuntimeCoordinator.lock.withLock {
            guard instance.hasMethod(named: action) else {
                throw AdaScriptError.invalidManifest("Unknown action '\(action)' in @view '\(identifier)'")
            }
            guard instance.callMethod(named: action, with: []) != nil else {
                let diagnostic = delegate.errors.last.map { ": \($0)" } ?? ""
                throw AdaScriptError.invalidManifest("Action '\(action)' failed in @view '\(identifier)'\(diagnostic)")
            }
        }
    }
}

@MainActor
final class AdaScriptViewStorage {
    var error: (any Error)?
    private(set) var model: AdaScriptViewModel?

    private let identifier: String
    private let instance: GSValue
    private let runtime: AdaScriptViewModuleRuntime
    private var environment: [String: EditorFieldValue] = [:]

    init(runtime: AdaScriptViewModuleRuntime, identifier: String) throws {
        self.identifier = identifier
        self.runtime = runtime
        let instance = try runtime.instantiate(identifier: identifier)
        self.instance = instance
        self.model = nil
    }

    func updateEnvironment(_ environment: [String: EditorFieldValue]) throws {
        guard model == nil || self.environment != environment else {
            return
        }
        self.environment = environment
        model = try runtime.evaluate(instance: instance, identifier: identifier, environment: environment)
    }

    func perform(action: String) throws {
        try runtime.perform(instance: instance, action: action, identifier: identifier)
        model = try runtime.evaluate(instance: instance, identifier: identifier, environment: environment)
        error = nil
    }
}

private extension UserInterfaceIdiom {
    var adaScriptName: String {
        switch self {
        case .desktop: "desktop"
        case .pad: "pad"
        case .phone: "phone"
        case .tv: "tv"
        case .xr: "xr"
        }
    }
}

private func defaultAdaScriptViewEnvironment() -> [String: EditorFieldValue] {
    [
        "colorScheme": .string("light"),
        "isEnabled": .bool(true),
        "scaleFactor": .double(1),
        "userInterfaceIdiom": .string("desktop")
    ]
}
