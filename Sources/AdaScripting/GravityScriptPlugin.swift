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

/// Selects how query results cross the Gravity bridge.
public enum GravityScriptExecutionMode: String, Sendable, Equatable {
    /// Passes a list of `AdaEntity` proxies. This is the simplest scripting API.
    case entities

    /// Passes one `AdaQueryBatch` per query and avoids allocating a bridge
    /// object for every matched entity.
    case batch
}

/// Describes one Gravity-backed ECS system.
public struct GravityScriptSystemDescriptor: Sendable, Equatable {
    public let executionMode: GravityScriptExecutionMode
    public let identifier: String
    public let queries: [GravityScriptQueryDescriptor]
    public let scheduler: SchedulerName

    public init(
        identifier: String,
        scheduler: SchedulerName = .update,
        queries: [GravityScriptQueryDescriptor],
        executionMode: GravityScriptExecutionMode = .entities
    ) {
        self.executionMode = executionMode
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

/// Loads one Ada Script source file (`.ada` or `.gravity`) as an AdaEngine plugin.
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
/// list of `AdaEntity` lists in the same order as the manifest. An entity can
/// read fields with `get(component, field)` and can write fields declared by
/// the query with `set(component, field, value)`.
///
/// Performance-sensitive systems can use `AdaSystem.createBatch(...)`. Their
/// `queries` argument contains `AdaQueryBatch` objects with `count`, `id(index)`,
/// `get(index, component, field)`, and `set(index, component, field, value)`.
public final class GravityScriptPlugin: Plugin, @unchecked Sendable {
    public let descriptor: GravityScriptPluginDescriptor

    public var pluginIdentifier: String {
        "AdaScripting.Gravity.\(descriptor.name)"
    }

    private let runtime: GravityScriptRuntime

    public convenience init(contentsOf fileURL: URL) throws {
        let source = try String(contentsOf: fileURL, encoding: .utf8)
        try self.init(source: source)
    }

    public init(source: String) throws {
        let runtime = try GravityScriptRuntime(source: source)
        self.runtime = runtime
        self.descriptor = runtime.descriptor
    }

    @MainActor
    public func setup(in app: borrowing AppWorlds) {
        for descriptor in descriptor.systems {
            let system: PreparedGravitySystem
            do {
                var queries: [PreparedGravityQuery] = []
                queries.reserveCapacity(descriptor.queries.count)
                for (queryIndex, queryDescriptor) in descriptor.queries.enumerated() {
                    queries.append(
                        try Self.makeQuery(
                            queryDescriptor,
                            systemIdentifier: descriptor.identifier,
                            queryIndex: queryIndex
                        )
                    )
                }
                system = PreparedGravitySystem(descriptor: descriptor, queries: queries)
            } catch {
                runtime.appendDiagnostic(error.description)
                continue
            }
            app.main.schedulers.addSystem(
                GravityScriptSystem(
                    pluginIdentifier: self.descriptor.name,
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

    /// Compiler and runtime diagnostics emitted by this plugin's VM.
    public var diagnostics: [String] {
        runtime.diagnostics
    }

    private static func makeQuery(
        _ descriptor: GravityScriptQueryDescriptor,
        systemIdentifier: String,
        queryIndex: Int
    ) throws(GravityScriptError) -> PreparedGravityQuery {
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
        var componentAccess: [String: GravityComponentAccess] = [:]
        for componentName in componentNames {
            guard let component = resolveComponent(named: componentName) else {
                continue
            }
            let typeName = String(reflecting: component)
            let reflectionDescriptor = EditorComponentReflectionRegistry.descriptor(named: typeName)
            componentAccess[componentName] = GravityComponentAccess(
                descriptor: reflectionDescriptor,
                fields: Dictionary(uniqueKeysWithValues: reflectionDescriptor?.fields.map { ($0.key, $0) } ?? []),
                typeName: typeName,
                isWritable: descriptor.writeComponents.contains(componentName)
            )
        }
        return PreparedGravityQuery(
            entityQuery: EntityQuery(where: predicate, access: access),
            componentAccess: componentAccess
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
}

private struct PreparedGravitySystem: Sendable {
    let descriptor: GravityScriptSystemDescriptor
    let queries: [PreparedGravityQuery]
}

private struct PreparedGravityQuery: Sendable {
    let entityQuery: EntityQuery
    let componentAccess: [String: GravityComponentAccess]
}

private struct GravityComponentAccess: Sendable {
    let descriptor: EditorComponentDescriptor?
    let fields: [String: EditorComponentFieldDescriptor]
    let typeName: String
    let isWritable: Bool
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
        return Self.makeSystemIdentifier(
            pluginIdentifier: pluginIdentifier,
            systemIdentifier: preparedSystem.descriptor.identifier
        )
    }

    var queries: SystemQueries {
        var parameters: [any SystemParameter] = preparedSystem?.queries.map { $0.entityQuery as any SystemParameter } ?? []
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

    private static func makeSystemIdentifier(pluginIdentifier: String, systemIdentifier: String) -> String {
        "AdaScripting.Gravity.\(pluginIdentifier.utf8.count):\(pluginIdentifier)\(systemIdentifier.utf8.count):\(systemIdentifier)"
    }

    func update(context: UpdateContext) async {
        guard let preparedSystem, let runtime else {
            return
        }
        let entityIdentifiers = preparedSystem.queries.map { query in
            query.entityQuery.wrappedValue.map(\.id)
        }
        runtime.update(
            systemIdentifier: preparedSystem.descriptor.identifier,
            deltaTime: Double(deltaTime.wrappedValue?.deltaTime ?? 0),
            queryEntityIdentifiers: entityIdentifiers,
            queryComponentAccess: preparedSystem.queries.map(\.componentAccess),
            world: context.world
        )
    }
}

/// A capability-scoped view of one entity for one script query.
///
/// The proxy intentionally does not expose `World`. Component names are
/// restricted to the query declaration, and writes are additionally restricted
/// to its `writeComponents` list.
@GSExportable("AdaEntity")
private final class GravityScriptEntity: @unchecked Sendable {
    let id: Int

    private let componentAccess: [String: GravityComponentAccess]
    private let reportDiagnostic: @Sendable (String) -> Void
    private let virtualMachine: GravityVirtualMachine
    private let world: World

    private init(
        id: Entity.ID,
        world: World,
        componentAccess: [String: GravityComponentAccess],
        reportDiagnostic: @escaping @Sendable (String) -> Void,
        virtualMachine: GravityVirtualMachine
    ) {
        self.id = id
        self.world = world
        self.componentAccess = componentAccess
        self.reportDiagnostic = reportDiagnostic
        self.virtualMachine = virtualMachine
    }

    @GSExportableIgnore
    static func make(
        id: Entity.ID,
        world: World,
        componentAccess: [String: GravityComponentAccess],
        reportDiagnostic: @escaping @Sendable (String) -> Void,
        virtualMachine: GravityVirtualMachine
    ) -> GravityScriptEntity {
        GravityScriptEntity(
            id: id,
            world: world,
            componentAccess: componentAccess,
            reportDiagnostic: reportDiagnostic,
            virtualMachine: virtualMachine
        )
    }

    func get(_ componentName: String, _ fieldName: String) -> GSValue {
        GravityScriptComponentBridge.get(
            entity: id,
            componentName: componentName,
            fieldName: fieldName,
            world: world,
            componentAccess: componentAccess,
            virtualMachine: virtualMachine
        )
    }

    @discardableResult
    func set(_ componentName: String, _ fieldName: String, _ value: GSValue) -> Bool {
        GravityScriptComponentBridge.set(
            entity: id,
            componentName: componentName,
            fieldName: fieldName,
            value: value,
            world: world,
            componentAccess: componentAccess,
            reportDiagnostic: reportDiagnostic
        )
    }
}

/// An indexed view over all entities matched by one native ECS query.
@GSExportable("AdaQueryBatch")
private final class GravityScriptQueryBatch: @unchecked Sendable {
    var count: Int {
        entityIdentifiers.count
    }

    private let componentAccess: [String: GravityComponentAccess]
    private let entityIdentifiers: [Entity.ID]
    private let reportDiagnostic: @Sendable (String) -> Void
    private let virtualMachine: GravityVirtualMachine
    private let world: World

    private init(
        entityIdentifiers: [Entity.ID],
        world: World,
        componentAccess: [String: GravityComponentAccess],
        reportDiagnostic: @escaping @Sendable (String) -> Void,
        virtualMachine: GravityVirtualMachine
    ) {
        self.entityIdentifiers = entityIdentifiers
        self.world = world
        self.componentAccess = componentAccess
        self.reportDiagnostic = reportDiagnostic
        self.virtualMachine = virtualMachine
    }

    @GSExportableIgnore
    static func make(
        entityIdentifiers: [Entity.ID],
        world: World,
        componentAccess: [String: GravityComponentAccess],
        reportDiagnostic: @escaping @Sendable (String) -> Void,
        virtualMachine: GravityVirtualMachine
    ) -> GravityScriptQueryBatch {
        GravityScriptQueryBatch(
            entityIdentifiers: entityIdentifiers,
            world: world,
            componentAccess: componentAccess,
            reportDiagnostic: reportDiagnostic,
            virtualMachine: virtualMachine
        )
    }

    func id(_ index: Int) -> Int {
        entityIdentifier(at: index) ?? -1
    }

    func get(_ index: Int, _ componentName: String, _ fieldName: String) -> GSValue {
        guard let entityIdentifier = entityIdentifier(at: index) else {
            return GSValue(nullIn: virtualMachine)
        }
        return GravityScriptComponentBridge.get(
            entity: entityIdentifier,
            componentName: componentName,
            fieldName: fieldName,
            world: world,
            componentAccess: componentAccess,
            virtualMachine: virtualMachine
        )
    }

    @discardableResult
    func set(_ index: Int, _ componentName: String, _ fieldName: String, _ value: GSValue) -> Bool {
        guard let entityIdentifier = entityIdentifier(at: index) else {
            return false
        }
        return GravityScriptComponentBridge.set(
            entity: entityIdentifier,
            componentName: componentName,
            fieldName: fieldName,
            value: value,
            world: world,
            componentAccess: componentAccess,
            reportDiagnostic: reportDiagnostic
        )
    }

    private func entityIdentifier(at index: Int) -> Entity.ID? {
        guard entityIdentifiers.indices.contains(index) else {
            reportDiagnostic("Query batch index \(index) is out of bounds for count \(entityIdentifiers.count)")
            return nil
        }
        return entityIdentifiers[index]
    }
}

private enum GravityScriptComponentBridge {
    static func get(
        entity: Entity.ID,
        componentName: String,
        fieldName: String,
        world: World,
        componentAccess: [String: GravityComponentAccess],
        virtualMachine: GravityVirtualMachine
    ) -> GSValue {
        guard let access = componentAccess[componentName],
              let field = access.fields[fieldName],
              let component = world.getComponent(named: access.typeName, from: entity),
              let value = field.read(component) else {
            return GSValue(nullIn: virtualMachine)
        }
        return makeGravityValue(value, virtualMachine: virtualMachine)
    }

    static func set(
        entity: Entity.ID,
        componentName: String,
        fieldName: String,
        value: GSValue,
        world: World,
        componentAccess: [String: GravityComponentAccess],
        reportDiagnostic: @Sendable (String) -> Void
    ) -> Bool {
        guard let access = componentAccess[componentName] else {
            reportDiagnostic("Component '\(componentName)' is not declared by this query")
            return false
        }
        guard access.isWritable else {
            return false
        }
        guard let descriptor = access.descriptor else {
            reportDiagnostic("Component '\(componentName)' does not expose reflected fields")
            return false
        }
        guard let field = access.fields[fieldName] else {
            reportDiagnostic("Unknown field '\(componentName).\(fieldName)'")
            return false
        }
        guard field.isEditable else {
            reportDiagnostic("Field '\(componentName).\(fieldName)' is read-only")
            return false
        }
        guard let fieldValue = makeEditorFieldValue(value) else {
            reportDiagnostic("Unsupported value for '\(componentName).\(fieldName)'")
            return false
        }
        guard field.accepts(fieldValue) else {
            reportDiagnostic("Invalid value for '\(componentName).\(fieldName)'")
            return false
        }
        guard descriptor.write(fieldValue, toField: fieldName, in: world, entity: entity) else {
            reportDiagnostic("Invalid value for '\(componentName).\(fieldName)'")
            return false
        }
        return true
    }

    private static func makeGravityValue(_ value: EditorFieldValue, virtualMachine: GravityVirtualMachine) -> GSValue {
        switch value {
        case .null:
            return GSValue(nullIn: virtualMachine)
        case .bool(let value):
            return GSValue(boolean: value, in: virtualMachine)
        case .int(let value):
            return GSValue(integer: value, in: virtualMachine)
        case .double(let value):
            return GSValue(double: value, in: virtualMachine)
        case .string(let value):
            return GSValue(string: value, in: virtualMachine)
        case .array(let values):
            return GSValue(newArrayIn: virtualMachine, items: values.map { makeGravityValue($0, virtualMachine: virtualMachine) as Any })
        case .object(let values):
            let colorKeys = ["red", "green", "blue", "alpha"]
            guard colorKeys.allSatisfy({ values[$0] != nil }) else {
                return GSValue(nullIn: virtualMachine)
            }
            return GSValue(
                newArrayIn: virtualMachine,
                items: colorKeys.compactMap { values[$0] }.map { makeGravityValue($0, virtualMachine: virtualMachine) as Any }
            )
        }
    }

    private static func makeEditorFieldValue(_ value: GSValue) -> EditorFieldValue? {
        if value.isNull || value.isUndefined {
            return .null
        }
        if value.isBool {
            return .bool(value.toBoolean)
        }
        if value.isInteger {
            guard let integer = Int(exactly: value.toInteger) else {
                return nil
            }
            return .int(integer)
        }
        if value.isDouble {
            return .double(value.toDouble)
        }
        if value.isString {
            return .string(value.toString)
        }
        if value.isList {
            var values: [EditorFieldValue] = []
            let list = value.toList
            values.reserveCapacity(list.count)
            for item in list {
                guard let fieldValue = makeEditorFieldValue(item) else {
                    return nil
                }
                values.append(fieldValue)
            }
            return .array(values)
        }
        return nil
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
            return [identifier, scheduler, queries, instance, "entities"];
        }

        static func createBatch(identifier, scheduler, queries, instance) {
            return [identifier, scheduler, queries, instance, "batch"];
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
        try virtualMachine.bindClass(with: GravityScriptEntity.self)
        try virtualMachine.bindClass(with: GravityScriptQueryBatch.self)
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
        queryEntityIdentifiers: [[Entity.ID]],
        queryComponentAccess: [[String: GravityComponentAccess]],
        world: World
    ) {
        Self.runtimeLock.lock()
        defer { Self.runtimeLock.unlock() }

        guard let system = loadedSystems.first(where: { $0.descriptor.identifier == systemIdentifier }),
              let virtualMachine else {
            return
        }
        let queryArgument: [Any]
        switch system.descriptor.executionMode {
        case .entities:
            queryArgument = zip(queryEntityIdentifiers, queryComponentAccess).map { identifiers, componentAccess in
                identifiers.map { identifier in
                    GravityScriptEntity.make(
                        id: identifier,
                        world: world,
                        componentAccess: componentAccess,
                        reportDiagnostic: { [delegate] message in
                            delegate.append(message)
                        },
                        virtualMachine: virtualMachine
                    ) as Any
                }
            }
        case .batch:
            queryArgument = zip(queryEntityIdentifiers, queryComponentAccess).map { identifiers, componentAccess in
                GravityScriptQueryBatch.make(
                    entityIdentifiers: identifiers,
                    world: world,
                    componentAccess: componentAccess,
                    reportDiagnostic: { [delegate] message in
                        delegate.append(message)
                    },
                    virtualMachine: virtualMachine
                ) as Any
            }
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

    var diagnostics: [String] {
        Self.runtimeLock.lock()
        defer { Self.runtimeLock.unlock() }
        return delegate.errors
    }

    func appendDiagnostic(_ message: String) {
        Self.runtimeLock.lock()
        defer { Self.runtimeLock.unlock() }
        delegate.append(message)
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
        guard fields.count == 4 || fields.count == 5,
              fields[0].isString,
              fields[1].isString,
              fields[2].isList,
              fields[3].isInstance,
              fields.count == 4 || fields[4].isString else {
            throw GravityScriptError.invalidManifest(
                "each system must be [identifier, scheduler, queries, instance, executionMode]"
            )
        }
        let executionModeName = fields.count == 5 ? fields[4].toString : GravityScriptExecutionMode.entities.rawValue
        guard let executionMode = GravityScriptExecutionMode(rawValue: executionModeName) else {
            throw GravityScriptError.invalidManifest("unknown system execution mode '\(executionModeName)'")
        }
        let queries = try fields[2].toList.map(parseQuery)
        return LoadedGravitySystem(
            descriptor: GravityScriptSystemDescriptor(
                identifier: fields[0].toString,
                scheduler: SchedulerName(rawValue: fields[1].toString),
                queries: queries,
                executionMode: executionMode
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

private final class GravityRuntimeDelegate: GravityVirtualMachineDelegate, @unchecked Sendable {
    private(set) var errors: [String] = []

    func append(_ message: String) {
        errors.append(message)
    }

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
