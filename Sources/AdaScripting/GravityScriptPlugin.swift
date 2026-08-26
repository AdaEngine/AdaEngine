import AdaApp
import AdaECS
import Foundation
import Gravity

/// A detached value returned by a Gravity system update.
public enum GravityScriptValue: Sendable, Equatable {
    case boolean(Bool)
    case double(Double)
    case integer(Int64)
    case list([GravityScriptValue])
    case null
    case string(String)
}

/// Describes one native ECS query declared by a script system.
public struct GravityScriptQueryDescriptor: Sendable, Equatable {
    public let components: [String]
    public let writeComponents: [String]

    public init(components: [String], writeComponents: [String] = []) {
        self.components = components
        self.writeComponents = writeComponents
    }
}

/// Describes one Gravity-backed ECS system.
public struct GravityScriptSystemDescriptor: Sendable, Equatable {
    public let identifier: String
    public let queries: [GravityScriptQueryDescriptor]
    public let scheduler: SchedulerName

    public init(
        identifier: String,
        scheduler: SchedulerName = .update,
        queries: [GravityScriptQueryDescriptor]
    ) {
        self.identifier = identifier
        self.scheduler = scheduler
        self.queries = queries
    }
}

/// Metadata exposed to the editor before a script plugin is installed.
public struct GravityScriptPluginDescriptor: Sendable, Equatable {
    public let name: String
    public let systems: [GravityScriptSystemDescriptor]

    public init(name: String, systems: [GravityScriptSystemDescriptor]) {
        self.name = name
        self.systems = systems
    }
}

public enum GravityScriptError: Error, Sendable, Equatable, CustomStringConvertible {
    case compilation([String])
    case invalidManifest(String)
    case unknownComponent(system: String, queryIndex: Int, component: String)

    public var description: String {
        switch self {
        case .compilation(let diagnostics):
            return diagnostics.joined(separator: "\n")
        case .invalidManifest(let message):
            return "Invalid Gravity plugin manifest: \(message)"
        case .unknownComponent(let system, let queryIndex, let component):
            return "Unknown component '\(component)' in query \(queryIndex) of system '\(system)'"
        }
    }
}

/// Loads one `.gravity` file as an AdaEngine plugin.
///
/// The script `main()` function returns a list in this shape:
///
/// ```gravity
/// AdaPlugin.create("PluginName", [
///     AdaSystem.create("system.id", "update", [
///         AdaQuery.readWrite(["Transform", "Velocity"], ["Transform"]),
///         AdaQuery.read(["Enemy"])
///     ], SystemInstance())
/// ])
/// ```
///
/// Each query is `[requiredComponents, writtenComponents]`. During update the
/// script instance receives `update(deltaTime, queries)`, where `queries` is a
/// list of entity-ID lists in the same order as the manifest.
public final class GravityScriptPlugin: Plugin, @unchecked Sendable {
    public let descriptor: GravityScriptPluginDescriptor

    public var pluginIdentifier: String {
        "AdaScripting.Gravity.\(descriptor.name)"
    }

    private let runtime: GravityScriptRuntime
    private let systems: [PreparedGravitySystem]

    public convenience init(contentsOf fileURL: URL) throws {
        let source = try String(contentsOf: fileURL, encoding: .utf8)
        try self.init(source: source)
    }

    public init(source: String) throws {
        let runtime = try GravityScriptRuntime(source: source)
        self.runtime = runtime
        self.descriptor = runtime.descriptor
        self.systems = try runtime.loadedSystems.map { loadedSystem in
            let queries = try loadedSystem.descriptor.queries.enumerated().map { queryIndex, descriptor in
                try Self.makeQuery(
                    descriptor,
                    systemIdentifier: loadedSystem.descriptor.identifier,
                    queryIndex: queryIndex
                )
            }
            return PreparedGravitySystem(
                descriptor: loadedSystem.descriptor,
                queries: queries
            )
        }
    }

    @MainActor
    public func setup(in app: borrowing AppWorlds) {
        for system in systems {
            app.main.schedulers.addSystem(
                GravityScriptSystem(
                    pluginIdentifier: descriptor.name,
                    runtime: runtime,
                    preparedSystem: system
                ),
                for: system.descriptor.scheduler
            )
        }
    }

    public func lastResult(for systemIdentifier: String) -> GravityScriptValue? {
        runtime.lastResult(for: systemIdentifier)
    }

    private static func makeQuery(
        _ descriptor: GravityScriptQueryDescriptor,
        systemIdentifier: String,
        queryIndex: Int
    ) throws -> EntityQuery {
        let componentNames = Array(Set(descriptor.components + descriptor.writeComponents)).sorted()
        var identifiers: [String: ComponentId] = [:]
        for componentName in componentNames {
            guard let component = resolveComponent(named: componentName) else {
                throw GravityScriptError.unknownComponent(
                    system: systemIdentifier,
                    queryIndex: queryIndex,
                    component: componentName
                )
            }
            identifiers[componentName] = component.identifier
        }

        let predicate = identifiers.values.reduce(QueryPredicate.all) { partialResult, component in
            partialResult && .has(component)
        }
        var access = SystemAccessSet()
        for componentName in descriptor.components {
            if let component = identifiers[componentName] {
                access.addComponentRead(component)
            }
        }
        for componentName in descriptor.writeComponents {
            if let component = identifiers[componentName] {
                access.addComponentWrite(component)
            }
        }
        return EntityQuery(where: predicate, access: access)
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
}

private struct PreparedGravitySystem: Sendable {
    let descriptor: GravityScriptSystemDescriptor
    let queries: [EntityQuery]
}

private struct GravityScriptSystem: System {
    private let deltaTime = Res<DeltaTime?>()
    private let pluginIdentifier: String
    private let preparedSystem: PreparedGravitySystem?
    private let runtime: GravityScriptRuntime?

    var systemIdentifier: String {
        guard let preparedSystem else {
            return "AdaScripting.Gravity.Unconfigured"
        }
        return "AdaScripting.Gravity.\(pluginIdentifier).\(preparedSystem.descriptor.identifier)"
    }

    var queries: SystemQueries {
        var parameters: [any SystemParameter] = preparedSystem?.queries.map { $0 as any SystemParameter } ?? []
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
        runtime: GravityScriptRuntime,
        preparedSystem: PreparedGravitySystem
    ) {
        self.pluginIdentifier = pluginIdentifier
        self.preparedSystem = preparedSystem
        self.runtime = runtime
    }

    func update(context: UpdateContext) async {
        guard let preparedSystem, let runtime else {
            return
        }
        let entityIdentifiers = preparedSystem.queries.map { query in
            query.wrappedValue.map(\.id)
        }
        runtime.update(
            systemIdentifier: preparedSystem.descriptor.identifier,
            deltaTime: Double(deltaTime.wrappedValue?.deltaTime ?? 0),
            queryEntityIdentifiers: entityIdentifiers
        )
    }
}

private final class GravityScriptRuntime: @unchecked Sendable {
    private static let runtimeLock = NSLock()
    private static let prelude = """
    class AdaQuery {
        static func read(components) {
            return [components, []];
        }

        static func write(components) {
            return [components, components];
        }

        static func readWrite(components, writeComponents) {
            return [components, writeComponents];
        }
    }

    class AdaSystem {
        static func create(identifier, scheduler, queries, instance) {
            return [identifier, scheduler, queries, instance];
        }
    }

    class AdaPlugin {
        static func create(name, systems) {
            return [name, systems];
        }
    }
    """

    let descriptor: GravityScriptPluginDescriptor
    private(set) var loadedSystems: [LoadedGravitySystem]

    private let delegate: GravityRuntimeDelegate
    private var lastResults: [String: GravityScriptValue] = [:]
    private var virtualMachine: GravityVirtualMachine?

    init(source: String) throws {
        let delegate = GravityRuntimeDelegate()
        self.delegate = delegate

        Self.runtimeLock.lock()
        defer { Self.runtimeLock.unlock() }

        let virtualMachine = GravityVirtualMachine(settings: .init(), delegate: delegate)
        self.virtualMachine = virtualMachine
        let binary = virtualMachine.loadGravityFile(from: Self.prelude + "\n" + source)
        if !delegate.errors.isEmpty {
            throw GravityScriptError.compilation(delegate.errors)
        }
        guard let manifest = virtualMachine.execute(binary) else {
            throw GravityScriptError.compilation(delegate.errors.isEmpty ? ["Gravity main() did not return a value"] : delegate.errors)
        }
        if !delegate.errors.isEmpty {
            throw GravityScriptError.compilation(delegate.errors)
        }
        let parsed = try Self.parseManifest(manifest)
        self.descriptor = parsed.descriptor
        self.loadedSystems = parsed.systems
    }

    deinit {
        Self.runtimeLock.lock()
        loadedSystems.removeAll(keepingCapacity: false)
        virtualMachine = nil
        Self.runtimeLock.unlock()
    }

    func update(
        systemIdentifier: String,
        deltaTime: Double,
        queryEntityIdentifiers: [[Entity.ID]]
    ) {
        Self.runtimeLock.lock()
        defer { Self.runtimeLock.unlock() }

        guard let system = loadedSystems.first(where: { $0.descriptor.identifier == systemIdentifier }) else {
            return
        }
        let queryArgument: [Any] = queryEntityIdentifiers.map { identifiers in
            identifiers.map { $0 as Any }
        }
        if let value = system.instance.callMethod(named: "update", with: [deltaTime, queryArgument]) {
            lastResults[systemIdentifier] = Self.detach(value)
        }
    }

    func lastResult(for systemIdentifier: String) -> GravityScriptValue? {
        Self.runtimeLock.lock()
        defer { Self.runtimeLock.unlock() }
        return lastResults[systemIdentifier]
    }

    private static func parseManifest(
        _ value: GSValue
    ) throws -> (descriptor: GravityScriptPluginDescriptor, systems: [LoadedGravitySystem]) {
        let root = value.toList
        guard root.count == 2, root[0].isString, root[1].isList else {
            throw GravityScriptError.invalidManifest("main() must return [pluginName, systems]")
        }
        let pluginName = root[0].toString
        let systems = try root[1].toList.map(parseSystem)
        let identifiers = systems.map(\.descriptor.identifier)
        guard Set(identifiers).count == identifiers.count else {
            throw GravityScriptError.invalidManifest("system identifiers must be unique")
        }
        return (
            GravityScriptPluginDescriptor(name: pluginName, systems: systems.map(\.descriptor)),
            systems
        )
    }

    private static func parseSystem(_ value: GSValue) throws -> LoadedGravitySystem {
        let fields = value.toList
        guard fields.count == 4,
              fields[0].isString,
              fields[1].isString,
              fields[2].isList,
              fields[3].isInstance else {
            throw GravityScriptError.invalidManifest(
                "each system must be [identifier, scheduler, queries, instance]"
            )
        }
        let queries = try fields[2].toList.map(parseQuery)
        return LoadedGravitySystem(
            descriptor: GravityScriptSystemDescriptor(
                identifier: fields[0].toString,
                scheduler: SchedulerName(rawValue: fields[1].toString),
                queries: queries
            ),
            instance: fields[3]
        )
    }

    private static func parseQuery(_ value: GSValue) throws -> GravityScriptQueryDescriptor {
        let fields = value.toList
        guard fields.count == 2, fields[0].isList, fields[1].isList else {
            throw GravityScriptError.invalidManifest(
                "each query must be [requiredComponents, writtenComponents]"
            )
        }
        return GravityScriptQueryDescriptor(
            components: try parseStringList(fields[0]),
            writeComponents: try parseStringList(fields[1])
        )
    }

    private static func parseStringList(_ value: GSValue) throws -> [String] {
        try value.toList.map { item in
            guard item.isString else {
                throw GravityScriptError.invalidManifest("component names must be strings")
            }
            return item.toString
        }
    }

    private static func detach(_ value: GSValue) -> GravityScriptValue {
        if value.isNull || value.isUndefined {
            return .null
        }
        if value.isBool {
            return .boolean(value.toBoolean)
        }
        if value.isInteger {
            return .integer(value.toInteger)
        }
        if value.isDouble {
            return .double(value.toDouble)
        }
        if value.isString {
            return .string(value.toString)
        }
        if value.isList {
            return .list(value.toList.map(detach))
        }
        return .string(value.toString)
    }
}

private struct LoadedGravitySystem {
    let descriptor: GravityScriptSystemDescriptor
    let instance: GSValue
}

private final class GravityRuntimeDelegate: GravityVirtualMachineDelegate {
    private(set) var errors: [String] = []

    func virtualMachineLoadFile(
        _ virtualMachine: GravityVirtualMachine,
        file: String,
        fileId: inout UInt32,
        isStatic: inout Bool
    ) -> String? {
        nil
    }

    func virtualMachine(
        _ virtualMachine: GravityVirtualMachine,
        didErrorWith message: String,
        errorType: error_type_t,
        errorDescription: error_desc_t
    ) {
        errors.append(message)
    }

    func virtualMachineDidReciveLog(_ virtualMachine: GravityVirtualMachine, message: String) {}
    func virtualMachineDidClearLog(_ virtualMachine: GravityVirtualMachine) {}

    func virtualMachineBridgeEquals(
        _ virtualMachine: GravityVirtualMachine,
        lhsValue: GSValue,
        rhsValue: GSValue
    ) -> Bool {
        false
    }

    func virtualMachine(
        _ virtualMachine: GravityVirtualMachine,
        didExecuteIn ctx: GSValue,
        arguments: [GSValue],
        argumentsCount: Int16,
        vIndex: UInt32
    ) -> Bool {
        false
    }

    func virtualMachine(
        _ virtualMachine: GravityVirtualMachine,
        didSetValue value: GSValue,
        in target: GSValue,
        forKey key: String
    ) -> Bool {
        false
    }

    func virtualMachine(
        _ virtualMachine: GravityVirtualMachine,
        didGetValueFrom target: GSValue,
        forKey key: String
    ) throws -> GSValue? {
        nil
    }

    func virtualMachine(
        _ virtualMachine: GravityVirtualMachine,
        didSetUndefValue value: GSValue,
        in target: GSValue,
        forKey key: String
    ) -> Bool {
        false
    }

    func virtualMachine(
        _ virtualMachine: GravityVirtualMachine,
        didGetUndefValueFrom target: GSValue,
        forKey key: String
    ) throws -> GSValue? {
        nil
    }

    func virtualMachine(_ virtualMachine: GravityVirtualMachine, didRequestStringWith length: UInt32) -> String {
        ""
    }
}
