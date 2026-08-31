import AdaApp
@_spi(Scripting) import AdaECS
import AdaScriptCompilerCore
import Foundation
import Gravity

/// Loads an annotation-driven Ada Script module.
///
/// Systems and queries are discovered from `@system` and `@query`
/// declarations. Ada Script modules do not define a `main()` function.
public final class GravityScriptPlugin: Plugin, @unchecked Sendable {
    public let name: String

    public var pluginIdentifier: String {
        "AdaScripting.Gravity.\(name)"
    }

    public var diagnostics: [String] {
        runtime.diagnostics
    }

    private let plans: [AnnotatedSystemPlan]
    private let runtime: AnnotatedGravityRuntime

    public convenience init(contentsOf fileURL: URL) throws {
        try self.init(
            sources: [
                GravityScriptSource(
                    path: fileURL.lastPathComponent,
                    source: String(contentsOf: fileURL, encoding: .utf8)
                )
            ],
            name: fileURL.deletingPathExtension().lastPathComponent
        )
    }

    public convenience init(source: String, name: String = "AdaScript") throws {
        try self.init(
            sources: [GravityScriptSource(path: "Main.ada", source: source)],
            name: name
        )
    }

    /// Creates one Ada Script module from a target-relative source map.
    public init(sources: [GravityScriptSource], name: String) throws {
        let module = try GravityScriptModuleResolver.resolve(sources)
        let runtime = try AnnotatedGravityRuntime(module: module)
        let resourceBindings = try AdaScriptSchemaParser.parseResourceBindings(sources: sources)
        let capabilities = try AdaScriptSchemaParser.parseSystemCapabilities(sources: sources)
        let plans = try Self.makePlans(
            from: runtime.annotations,
            resourceBindings: resourceBindings,
            systemCapabilities: capabilities
        )
        self.name = name
        self.runtime = runtime
        self.plans = plans
        try runtime.instantiateSystems(plans)
    }

    @MainActor
    public func setup(in app: borrowing AppWorlds) {
        for plan in plans {
            do {
                let prepared = try Self.prepare(plan, world: app.main)
                app.main.schedulers.addSystem(
                    AnnotatedGravityScriptSystem(
                        pluginIdentifier: name,
                        runtime: runtime,
                        preparedSystem: prepared
                    ),
                    for: prepared.scheduler
                )
            } catch {
                runtime.appendDiagnostic(String(describing: error))
            }
        }
    }

    private static func makePlans(
        from annotations: [GravityAnnotation],
        resourceBindings: [AdaScriptResourceBinding],
        systemCapabilities: [AdaScriptSystemCapabilities]
    ) throws -> [AnnotatedSystemPlan] {
        let systemAnnotations = annotations.filter { $0.name == "system" }
        guard !systemAnnotations.isEmpty else {
            throw GravityScriptError.invalidManifest("Ada Script module must declare at least one @system class")
        }

        let systemClassNames = Set(systemAnnotations.map(\.target.identifier))
        for query in annotations where query.name == "query" {
            guard let parent = query.target.parentIdentifier, systemClassNames.contains(parent) else {
                throw GravityScriptError.invalidManifest("@query must be declared inside an @system class")
            }
        }

        var identifiers = Set<String>()
        return try systemAnnotations.map { annotation in
            guard annotation.target.kind == .class else {
                throw GravityScriptError.invalidManifest("@system can only annotate a class")
            }
            let className = annotation.target.identifier
            let identifier = annotation.stringArgument(label: "id") ?? className
            guard identifiers.insert(identifier).inserted else {
                throw GravityScriptError.invalidManifest("system identifiers must be unique")
            }
            let scheduler = SchedulerName(rawValue: annotation.stringArgument(label: "scheduler") ?? "update")
            let queryPlans = try annotations
                .filter { $0.name == "query" && $0.target.parentIdentifier == className }
                .map(makeQueryPlan)
            return AnnotatedSystemPlan(
                className: className,
                identifier: identifier,
                scheduler: scheduler,
                queries: queryPlans,
                resources: resourceBindings
                    .filter { $0.systemName == className }
                    .map {
                        AnnotatedResourcePlan(
                            isOptional: $0.isOptional,
                            propertyName: $0.propertyName,
                            resourceName: $0.resourceName
                        )
                    },
                usesDeferredCommands: systemCapabilities
                    .first { $0.systemName == className }?
                    .usesDeferredCommands == true
            )
        }
    }

    private static func makeQueryPlan(_ annotation: GravityAnnotation) throws -> AnnotatedQueryPlan {
        guard annotation.target.kind == .variableDeclaration else {
            throw GravityScriptError.invalidManifest("@query can only annotate a stored property")
        }
        let components = annotation.arguments.compactMap { argument -> String? in
            guard argument.label == nil else {
                return nil
            }
            return argument.value.identifierValue
        }
        guard !components.isEmpty else {
            throw GravityScriptError.invalidManifest("@query requires at least one fetched component")
        }
        return AnnotatedQueryPlan(
            propertyName: annotation.target.identifier,
            components: components,
            withComponents: annotation.identifierListArgument(label: "with"),
            withoutComponents: annotation.identifierListArgument(label: "without")
        )
    }

    private static func prepare(_ plan: AnnotatedSystemPlan, world: World) throws -> PreparedAnnotatedSystem {
        let queries = try plan.queries.enumerated().map { queryIndex, query in
            try prepareQuery(query, systemIdentifier: plan.identifier, queryIndex: queryIndex)
        }
        let resources = try plan.resources.map { resource in
            try prepareResource(resource, systemIdentifier: plan.identifier)
        }
        return PreparedAnnotatedSystem(
            className: plan.className,
            commands: plan.usesDeferredCommands ? Commands(entities: world.entities, commandsQueue: world.commandQueue) : nil,
            identifier: plan.identifier,
            scheduler: plan.scheduler,
            queries: queries,
            resources: resources
        )
    }

    private static func prepareResource(
        _ plan: AnnotatedResourcePlan,
        systemIdentifier: String
    ) throws -> PreparedAnnotatedResource {
        guard let resourceType = RuntimeTypeRegistry.resourceType(named: plan.resourceName) else {
            throw GravityScriptError.unknownResource(system: systemIdentifier, resource: plan.resourceName)
        }
        let descriptor = RuntimeResourceReflectionRegistry.descriptor(for: resourceType)
        return PreparedAnnotatedResource(
            fields: Dictionary(uniqueKeysWithValues: descriptor?.fields.map { ($0.key, $0) } ?? []),
            parameter: DynamicResource(resourceType: resourceType, isOptional: plan.isOptional, writable: true),
            propertyName: plan.propertyName,
            resourceName: plan.resourceName
        )
    }

    private static func prepareQuery(
        _ plan: AnnotatedQueryPlan,
        systemIdentifier: String,
        queryIndex: Int
    ) throws -> PreparedAnnotatedQuery {
        var resolved: [String: any Component.Type] = [:]
        let allNames = plan.components + plan.withComponents + plan.withoutComponents
        for name in allNames where resolved[name] == nil {
            guard let component = resolveComponent(named: name) else {
                throw GravityScriptError.unknownComponent(
                    system: systemIdentifier,
                    queryIndex: queryIndex,
                    component: name
                )
            }
            resolved[name] = component
        }

        var predicate = QueryPredicate.all
        for name in plan.components + plan.withComponents {
            if let component = resolved[name] {
                predicate = predicate && .has(component.identifier)
            }
        }
        for name in plan.withoutComponents {
            if let component = resolved[name] {
                predicate = predicate && .without(component.identifier)
            }
        }

        var access = SystemAccessSet()
        let componentAccesses = plan.components.enumerated().compactMap { index, name -> AnnotatedComponentAccess? in
            guard let component = resolved[name] else {
                return nil
            }
            // The first vertical slice conservatively grants write access to
            // fetched components. Static access inference will narrow this set.
            access.addComponentWrite(component.identifier)
            let typeName = String(reflecting: component)
            let descriptor = EditorComponentReflectionRegistry.descriptor(named: typeName)
            return AnnotatedComponentAccess(
                alias: defaultAlias(for: name),
                componentIndex: index,
                fields: Dictionary(uniqueKeysWithValues: descriptor?.fields.map { ($0.key, $0) } ?? [])
            )
        }

        let componentIDs = plan.components.compactMap { resolved[$0]?.identifier }
        return PreparedAnnotatedQuery(
            propertyName: plan.propertyName,
            query: DynamicQuery(where: predicate, components: componentIDs, access: access),
            componentAccesses: componentAccesses
        )
    }

    private static func resolveComponent(named name: String) -> (any Component.Type)? {
        if let exact = RuntimeTypeRegistry.componentType(named: name) {
            return exact
        }
        let matches = RuntimeTypeRegistry.registeredComponentTypes().filter { registeredName, _ in
            registeredName == name || registeredName.hasSuffix(".\(name)")
        }
        guard matches.count == 1 else {
            return nil
        }
        return matches.first?.value
    }

    private static func defaultAlias(for componentName: String) -> String {
        let shortName = componentName.split(separator: ".").last.map(String.init) ?? componentName
        guard let first = shortName.first else {
            return shortName
        }
        return first.lowercased() + shortName.dropFirst()
    }
}

private struct AnnotatedSystemPlan: Sendable {
    let className: String
    let identifier: String
    let scheduler: SchedulerName
    let queries: [AnnotatedQueryPlan]
    let resources: [AnnotatedResourcePlan]
    let usesDeferredCommands: Bool
}

private struct AnnotatedResourcePlan: Sendable {
    let isOptional: Bool
    let propertyName: String
    let resourceName: String
}

private struct AnnotatedQueryPlan: Sendable {
    let propertyName: String
    let components: [String]
    let withComponents: [String]
    let withoutComponents: [String]
}

private struct PreparedAnnotatedSystem: Sendable {
    let className: String
    let commands: Commands?
    let identifier: String
    let scheduler: SchedulerName
    let queries: [PreparedAnnotatedQuery]
    let resources: [PreparedAnnotatedResource]
}

private struct PreparedAnnotatedResource: Sendable {
    let fields: [String: EditorComponentFieldDescriptor]
    let parameter: DynamicResource
    let propertyName: String
    let resourceName: String
}

private struct PreparedAnnotatedQuery: Sendable {
    let propertyName: String
    let query: DynamicQuery
    let componentAccesses: [AnnotatedComponentAccess]
}

struct AnnotatedComponentAccess: Sendable {
    let alias: String
    let componentIndex: Int
    let fields: [String: EditorComponentFieldDescriptor]
}

private struct AnnotatedGravityScriptSystem: System {
    private let deltaTime = Res<DeltaTime?>()
    private let pluginIdentifier: String
    private let preparedSystem: PreparedAnnotatedSystem?
    private let runtime: AnnotatedGravityRuntime?

    var systemIdentifier: String {
        guard let preparedSystem else {
            return "AdaScripting.Gravity.Unconfigured"
        }
        return "AdaScripting.Gravity.\(pluginIdentifier.utf8.count):\(pluginIdentifier)\(preparedSystem.identifier.utf8.count):\(preparedSystem.identifier)"
    }

    var queries: SystemQueries {
        var parameters: [any SystemParameter] = preparedSystem?.queries.map { $0.query as any SystemParameter } ?? []
        parameters += preparedSystem?.resources.map { $0.parameter as any SystemParameter } ?? []
        if let commands = preparedSystem?.commands {
            parameters.append(commands)
        }
        parameters.append(deltaTime)
        return SystemQueries(queries: parameters)
    }

    init(world: World) {
        self.pluginIdentifier = "Unconfigured"
        self.preparedSystem = nil
        self.runtime = nil
    }

    init(
        pluginIdentifier: String,
        runtime: AnnotatedGravityRuntime,
        preparedSystem: PreparedAnnotatedSystem
    ) {
        self.pluginIdentifier = pluginIdentifier
        self.runtime = runtime
        self.preparedSystem = preparedSystem
    }

    func update(context: UpdateContext) async {
        guard let preparedSystem, let runtime else {
            return
        }
        let queries = preparedSystem.queries.map { query in
            runtime.makeQueryBridge(
                cursor: query.query.wrappedValue.makeCursor(),
                componentAccesses: query.componentAccesses,
            )
        }
        let resources = preparedSystem.resources.map { resource in
            (
                propertyName: resource.propertyName,
                resource: runtime.makeResourceBridge(
                    parameter: resource.parameter.wrappedValue,
                    fields: resource.fields,
                    resourceName: resource.resourceName
                )
            )
        }
        let world = runtime.makeWorldBridge(commands: preparedSystem.commands)
        runtime.update(
            className: preparedSystem.className,
            systemIdentifier: preparedSystem.identifier,
            deltaTime: Double(deltaTime.wrappedValue?.deltaTime ?? 0),
            queries: zip(preparedSystem.queries, queries).map { ($0.propertyName, $1) },
            resources: resources,
            world: world
        )
    }
}

private final class AnnotatedGravityRuntime: @unchecked Sendable {
    private static let runtimeLock = NSRecursiveLock()

    let annotations: [GravityAnnotation]

    // The runtime owns its delegate for exactly the VM lifetime; this is not a callback back-reference.
    // swiftlint:disable:next weak_delegate
    private let delegate: AnnotatedGravityRuntimeDelegate
    private let virtualMachine: GravityVirtualMachine
    private var instances: [String: GSValue] = [:]

    init(module: ResolvedGravityScriptModule) throws {
        let delegate = AnnotatedGravityRuntimeDelegate(module: module)
        self.delegate = delegate

        Self.runtimeLock.lock()
        defer { Self.runtimeLock.unlock() }

        let virtualMachine = GravityVirtualMachine(settings: .init(), delegate: delegate)
        self.virtualMachine = virtualMachine
        try virtualMachine.bindClass(with: AnnotatedGravitySystemContext.self)
        try virtualMachine.bindClass(with: AnnotatedGravityWorldContext.self)
        try virtualMachine.bindClass(with: AnnotatedGravityCommandsBridge.self)
        try virtualMachine.bindClass(with: AnnotatedGravityQueryBridge.self)
        try virtualMachine.bindClass(with: AnnotatedGravityQueryRow.self)
        try virtualMachine.bindClass(with: AnnotatedGravityComponentView.self)
        try virtualMachine.bindClass(with: AnnotatedGravityResourceView.self)

        let binary = virtualMachine.loadGravityFile(from: module.entrySource)
        guard delegate.errors.isEmpty else {
            throw GravityScriptError.compilation(delegate.errors)
        }
        self.annotations = binary.annotations
        virtualMachine.load(binary)
        guard delegate.errors.isEmpty else {
            throw GravityScriptError.compilation(delegate.errors)
        }
        if virtualMachine.getValue(forKey: "main").isClosure {
            throw GravityScriptError.invalidManifest("Ada Script modules must not declare main()")
        }
    }

    func instantiateSystems(_ plans: [AnnotatedSystemPlan]) throws {
        Self.runtimeLock.lock()
        defer { Self.runtimeLock.unlock() }
        for plan in plans {
            let systemClass = virtualMachine.getValue(forKey: plan.className)
            guard systemClass.isClass, let instance = systemClass.callAsFunction(), instance.isInstance else {
                throw GravityScriptError.invalidManifest("Unable to instantiate @system class '\(plan.className)'")
            }
            guard instance.hasMethod(named: "update") else {
                throw GravityScriptError.invalidManifest("@system class '\(plan.className)' must define update(context)")
            }
            instances[plan.className] = instance
        }
    }

    func update(
        className: String,
        systemIdentifier: String,
        deltaTime: Double,
        queries: [(propertyName: String, query: AnnotatedGravityQueryBridge)],
        resources: [(propertyName: String, resource: AnnotatedGravityResourceView)],
        world: AnnotatedGravityWorldContext
    ) {
        Self.runtimeLock.lock()
        defer { Self.runtimeLock.unlock() }
        defer { world.invalidate() }

        guard let instance = instances[className] else {
            return
        }

        for (propertyName, query) in queries {
            let queryValue = GSValue(object: query, in: virtualMachine)
            guard instance.setStoredProperty(named: propertyName, to: queryValue) else {
                delegate.append("Unable to bind @query property '\(propertyName)' in system '\(systemIdentifier)'")
                return
            }
        }
        for (propertyName, resource) in resources {
            let resourceValue = GSValue(object: resource, in: virtualMachine)
            guard instance.setStoredProperty(named: propertyName, to: resourceValue) else {
                delegate.append("Unable to bind @res property '\(propertyName)' in system '\(systemIdentifier)'")
                return
            }
        }
        let context = AnnotatedGravitySystemContext.make(deltaTime: deltaTime, world: world)
        _ = instance.callMethod(named: "update", with: [context])
    }

    func makeQueryBridge(
        cursor: DynamicQueryCursor,
        componentAccesses: [AnnotatedComponentAccess]
    ) -> AnnotatedGravityQueryBridge {
        AnnotatedGravityQueryBridge.make(
            cursor: cursor,
            componentAccesses: componentAccesses,
            reportDiagnostic: appendDiagnostic,
            virtualMachine: virtualMachine
        )
    }

    func makeResourceBridge(
        parameter: DynamicResource,
        fields: [String: EditorComponentFieldDescriptor],
        resourceName: String
    ) -> AnnotatedGravityResourceView {
        if !parameter.isAvailable && !parameter.isOptional {
            appendDiagnostic("Required resource '\(resourceName)' is not available")
        }
        return AnnotatedGravityResourceView.make(
            parameter: parameter,
            fields: fields,
            reportDiagnostic: appendDiagnostic,
            virtualMachine: virtualMachine
        )
    }

    func makeWorldBridge(commands: Commands?) -> AnnotatedGravityWorldContext {
        AnnotatedGravityWorldContext.make(
            commands: AnnotatedGravityCommandsBridge.make(
                commands: commands,
                reportDiagnostic: appendDiagnostic
            )
        )
    }

    var diagnostics: [String] {
        Self.runtimeLock.withLock { delegate.errors }
    }

    func appendDiagnostic(_ message: String) {
        Self.runtimeLock.withLock { delegate.append(message) }
    }
}
