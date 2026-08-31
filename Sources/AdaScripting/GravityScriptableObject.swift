@_spi(Scripting) import AdaECS
import AdaInput
@_spi(Scripting) import AdaScene
import Foundation
import Gravity

public struct GravityScriptableSchema: Sendable {
    public let aliases: [String]
    public let bindings: [GravityScriptableBinding]
    public let className: String
    public let fields: [String: EditorFieldValue]
    public let identifier: String
    public let version: Int

    public init(
        identifier: String,
        className: String,
        version: Int,
        aliases: [String],
        bindings: [GravityScriptableBinding] = [],
        fields: [String: EditorFieldValue]
    ) {
        self.aliases = aliases
        self.bindings = bindings
        self.className = className
        self.fields = fields
        self.identifier = identifier
        self.version = version
    }
}

public struct GravityScriptableBinding: Sendable {
    public enum Kind: Sendable {
        case component(required: Bool)
        case resource(optional: Bool)
    }

    public let kind: Kind
    public let propertyName: String
    public let typeName: String

    public init(kind: Kind, propertyName: String, typeName: String) {
        self.kind = kind
        self.propertyName = propertyName
        self.typeName = typeName
    }
}

public enum GravityScriptableObjectRegistration {
    @MainActor
    public static func register(
        schemas: [GravityScriptableSchema],
        sources: [GravityScriptSource],
        moduleName: String
    ) throws {
        _ = moduleName
        guard !schemas.isEmpty else {
            return
        }
        let runtime = try GravityScriptableModuleRuntime(
            sources: sources,
            schemas: schemas
        )
        for schema in schemas {
            let definition = try GravityScriptableDefinition(schema: schema, runtime: runtime)
            try ScriptableObjectRegistry.register(
                ScriptableObjectDescriptor(
                    identifier: schema.identifier,
                    version: schema.version,
                    aliases: schema.aliases,
                    declaredAccess: definition.declaredAccess,
                    exportedFields: schema.fields,
                    requiredComponents: definition.requiredComponents,
                    make: { GravityScriptableObject(definition: definition) },
                    decode: { decoder, encodedVersion in
                        let object = try GravityScriptableObject(
                            definition: definition,
                            payload: GravityScriptablePayload.decode(from: decoder)
                        )
                        object.encodedSchemaVersion = encodedVersion
                        return object
                    }
                )
            )
        }
    }
}

private final class GravityScriptableDefinition: @unchecked Sendable {
    let bindings: [ResolvedGravityScriptableBinding]
    let declaredAccess: SystemAccessSet
    let requiredComponents: [ComponentId]
    let runtime: GravityScriptableModuleRuntime
    let schema: GravityScriptableSchema

    init(schema: GravityScriptableSchema, runtime: GravityScriptableModuleRuntime) throws {
        let bindings = try schema.bindings.map {
            try Self.resolve($0, scriptableIdentifier: schema.identifier)
        }
        self.bindings = bindings
        var access = SystemAccessSet()
        var requiredComponents: [ComponentId] = []
        for binding in bindings {
            switch binding {
            case let .component(_, type, _, required):
                access.addComponentWrite(type.identifier)
                if required {
                    requiredComponents.append(type.identifier)
                }
            case let .resource(_, type, _, _):
                access.addResourceWrite(ObjectIdentifier(type))
            }
        }
        access.addDeferredWorldAccess()
        self.declaredAccess = access
        self.requiredComponents = requiredComponents
        self.runtime = runtime
        self.schema = schema
    }

    private static func resolve(
        _ binding: GravityScriptableBinding,
        scriptableIdentifier: String
    ) throws -> ResolvedGravityScriptableBinding {
        switch binding.kind {
        case .component(let required):
            guard let type = RuntimeTypeRegistry.componentType(named: binding.typeName) else {
                throw GravityScriptError.unknownComponent(
                    system: scriptableIdentifier,
                    queryIndex: 0,
                    component: binding.typeName
                )
            }
            return .component(
                propertyName: binding.propertyName,
                type: type,
                descriptor: EditorComponentReflectionRegistry.descriptor(named: String(reflecting: type)),
                required: required
            )
        case .resource(let optional):
            guard let type = RuntimeTypeRegistry.resourceType(named: binding.typeName) else {
                throw GravityScriptError.unknownResource(
                    system: scriptableIdentifier,
                    resource: binding.typeName
                )
            }
            let fields = RuntimeResourceReflectionRegistry.descriptor(for: type)?.fields ?? []
            return .resource(
                propertyName: binding.propertyName,
                type: type,
                fields: Dictionary(uniqueKeysWithValues: fields.map { ($0.key, $0) }),
                optional: optional
            )
        }
    }

    func validateRequiredBindings(context: ScriptableObjectContext) throws {
        for binding in bindings {
            guard case let .component(propertyName, type, _, required) = binding,
                  required,
                  !context.scriptingWorld.has(type.identifier, in: context.entityID) else {
                continue
            }
            throw GravityScriptError.invalidManifest(
                "Required component '\(String(describing: type))' for '\(propertyName)' is missing"
            )
        }
    }
}

private enum ResolvedGravityScriptableBinding: @unchecked Sendable {
    case component(
        propertyName: String,
        type: any Component.Type,
        descriptor: EditorComponentDescriptor?,
        required: Bool
    )
    case resource(
        propertyName: String,
        type: any Resource.Type,
        fields: [String: EditorComponentFieldDescriptor],
        optional: Bool
    )
}

private final class GravityScriptableObject: ScriptableObject, @unchecked Sendable {
    override var explicitTypeIdentifier: String? { definition.schema.identifier }

    private let definition: GravityScriptableDefinition
    private var instanceID: UUID?
    private var payload: [String: EditorFieldValue]

    // A module definition is required and cannot be recovered by the base initializer.
    // swiftlint:disable:next unavailable_function
    required init() {
        fatalError("GravityScriptableObject must be created from a registered descriptor")
    }

    init(
        definition: GravityScriptableDefinition,
        payload: [String: EditorFieldValue]? = nil
    ) {
        self.definition = definition
        self.payload = definition.schema.fields.merging(payload ?? [:]) { _, decoded in decoded }
        super.init()
    }

    required init(from decoder: Decoder) throws {
        throw ScriptableObjectCodingError.unregisteredRuntimeType("GravityScriptableObject")
    }

    override func encode(to encoder: Encoder) throws {
        if let instanceID {
            payload = definition.runtime.snapshot(instanceID: instanceID, fields: definition.schema.fields.keys)
        }
        try GravityScriptablePayload.encode(payload, to: encoder)
    }

    override func ready(context: ScriptableObjectContext) {
        do {
            try definition.validateRequiredBindings(context: context)
            let instanceID = try definition.runtime.instantiate(
                className: definition.schema.className,
                payload: payload
            )
            self.instanceID = instanceID
            definition.runtime.call(
                instanceID: instanceID,
                method: "ready",
                context: context,
                bindings: definition.bindings
            )
            refreshPayload()
        } catch {
            assertionFailure(String(describing: error))
        }
    }

    override func update(context: ScriptableObjectContext) {
        call(method: "update", context: context)
    }

    override func fixedUpdate(context: ScriptableObjectContext) {
        call(method: "fixedUpdate", context: context)
    }

    override func event(_ events: [any InputEvent], context: ScriptableObjectContext) {
        guard let instanceID else {
            return
        }
        definition.runtime.callEvent(
            instanceID: instanceID,
            events: events.map { String(reflecting: type(of: $0)) },
            context: context,
            bindings: definition.bindings
        )
        refreshPayload()
    }

    override func destroy(context: ScriptableObjectContext) {
        guard let instanceID else {
            return
        }
        definition.runtime.call(
            instanceID: instanceID,
            method: "destroy",
            context: context,
            bindings: definition.bindings
        )
        refreshPayload()
        definition.runtime.remove(instanceID: instanceID)
        self.instanceID = nil
    }

    private func call(method: String, context: ScriptableObjectContext) {
        guard let instanceID else {
            return
        }
        definition.runtime.call(
            instanceID: instanceID,
            method: method,
            context: context,
            bindings: definition.bindings
        )
        refreshPayload()
    }

    private func refreshPayload() {
        guard let instanceID else {
            return
        }
        payload = definition.runtime.snapshot(instanceID: instanceID, fields: definition.schema.fields.keys)
    }
}

@GSExportable("AdaScriptableContext")
private final class GravityScriptableLifecycleContext: @unchecked Sendable {
    let deltaTime: Double
    let entityID: Int
    let world: AnnotatedGravityWorldContext

    @GSExportableIgnore
    static func make(
        _ context: ScriptableObjectContext,
        reportDiagnostic: @escaping @Sendable (String) -> Void
    ) -> GravityScriptableLifecycleContext {
        GravityScriptableLifecycleContext(
            deltaTime: Double(context.deltaTime),
            entityID: context.entityID,
            world: AnnotatedGravityWorldContext.make(
                commands: AnnotatedGravityCommandsBridge.make(
                    commands: context.scriptingCommands,
                    reportDiagnostic: reportDiagnostic
                )
            )
        )
    }

    private init(deltaTime: Double, entityID: Int, world: AnnotatedGravityWorldContext) {
        self.deltaTime = deltaTime
        self.entityID = entityID
        self.world = world
    }
}

private final class GravityScriptableModuleRuntime: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private let factoryNamesByClass: [String: String]
    private let getterNamesByClass: [String: [String: String]]
    // The runtime owns its delegate for exactly the VM lifetime; this is not a callback back-reference.
    // swiftlint:disable:next weak_delegate
    private let delegate: AnnotatedGravityRuntimeDelegate
    private let virtualMachine: GravityVirtualMachine
    private var classNamesByInstance: [UUID: String] = [:]
    private var instances: [UUID: GSValue] = [:]

    init(sources: [GravityScriptSource], schemas: [GravityScriptableSchema]) throws {
        let module = try GravityScriptModuleResolver.resolve(sources)
        let factoryNamesByClass = Dictionary(uniqueKeysWithValues: schemas.enumerated().map { index, schema in
            (schema.className, "__ada_make_scriptable_\(index)")
        })
        self.factoryNamesByClass = factoryNamesByClass
        let getterNamesByClass = Dictionary(uniqueKeysWithValues: schemas.enumerated().map { schemaIndex, schema in
            let names = Dictionary(uniqueKeysWithValues: schema.fields.keys.sorted().enumerated().map { fieldIndex, field in
                (field, "__ada_get_scriptable_\(schemaIndex)_\(fieldIndex)")
            })
            return (schema.className, names)
        })
        self.getterNamesByClass = getterNamesByClass
        let delegate = AnnotatedGravityRuntimeDelegate(module: module)
        self.delegate = delegate
        let virtualMachine = GravityVirtualMachine(settings: .init(), delegate: delegate)
        self.virtualMachine = virtualMachine

        try virtualMachine.bindClass(with: GravityScriptableLifecycleContext.self)
        try virtualMachine.bindClass(with: AnnotatedGravitySystemContext.self)
        try virtualMachine.bindClass(with: AnnotatedGravityWorldContext.self)
        try virtualMachine.bindClass(with: AnnotatedGravityCommandsBridge.self)
        try virtualMachine.bindClass(with: AnnotatedGravityQueryBridge.self)
        try virtualMachine.bindClass(with: AnnotatedGravityQueryRow.self)
        try virtualMachine.bindClass(with: AnnotatedGravityComponentView.self)
        try virtualMachine.bindClass(with: AnnotatedGravityResourceView.self)
        try virtualMachine.bindClass(with: GravityAttachedComponentView.self)
        try virtualMachine.bindClass(with: GravityAttachedResourceView.self)
        let factories = factoryNamesByClass
            .map { className, factoryName in
                "func \(factoryName)() { return \(className)(); }"
            }
            .sorted()
        let getters = schemas
            .flatMap { schema in
                getterNamesByClass[schema.className, default: [:]].map { field, getterName in
                    "func \(getterName)(instance) { return instance.\(field); }"
                }
            }
            .sorted()
        let generatedSource = (factories + getters).joined(separator: "\n")
        let binary = virtualMachine.loadGravityFile(from: module.entrySource + "\n" + generatedSource)
        guard delegate.errors.isEmpty else {
            throw GravityScriptError.compilation(delegate.errors)
        }
        virtualMachine.load(binary)
        guard delegate.errors.isEmpty else {
            throw GravityScriptError.compilation(delegate.errors)
        }
    }

    func instantiate(className: String, payload: [String: EditorFieldValue]) throws -> UUID {
        try lock.withLock {
            guard let factoryName = factoryNamesByClass[className] else {
                throw GravityScriptError.invalidManifest("Missing @scriptable factory for '\(className)'")
            }
            let factory = virtualMachine.getValue(forKey: factoryName)
            guard factory.isClosure,
                  let instance = factory.callConstructor(with: []),
                  instance.isInstance else {
                throw GravityScriptError.invalidManifest("Unable to instantiate @scriptable class '\(className)'")
            }
            for (name, value) in payload {
                _ = instance.setStoredProperty(
                    named: name,
                    to: AnnotatedGravityValueBridge.makeGravityValue(value, virtualMachine: virtualMachine)
                )
            }
            let identifier = UUID()
            instances[identifier] = instance
            classNamesByInstance[identifier] = className
            return identifier
        }
    }

    func call(
        instanceID: UUID,
        method: String,
        context: ScriptableObjectContext,
        bindings: [ResolvedGravityScriptableBinding]
    ) {
        lock.withLock {
            guard let instance = instances[instanceID], instance.hasMethod(named: method) else {
                return
            }
            bind(bindings, to: instance, context: context)
            let lifecycleContext = GravityScriptableLifecycleContext.make(
                context,
                reportDiagnostic: delegate.append
            )
            defer { lifecycleContext.world.invalidate() }
            _ = instance.callMethod(
                named: method,
                with: [lifecycleContext]
            )
        }
    }

    func callEvent(
        instanceID: UUID,
        events: [String],
        context: ScriptableObjectContext,
        bindings: [ResolvedGravityScriptableBinding]
    ) {
        lock.withLock {
            guard let instance = instances[instanceID], instance.hasMethod(named: "event") else {
                return
            }
            bind(bindings, to: instance, context: context)
            let lifecycleContext = GravityScriptableLifecycleContext.make(
                context,
                reportDiagnostic: delegate.append
            )
            defer { lifecycleContext.world.invalidate() }
            _ = instance.callMethod(
                named: "event",
                with: [events, lifecycleContext]
            )
        }
    }

    func snapshot(
        instanceID: UUID,
        fields: [String: EditorFieldValue].Keys
    ) -> [String: EditorFieldValue] {
        lock.withLock {
            guard let instance = instances[instanceID] else {
                return [:]
            }
            guard let className = classNamesByInstance[instanceID],
                  let getterNames = getterNamesByClass[className] else {
                return [:]
            }
            return fields.reduce(into: [:]) { result, field in
                guard let getterName = getterNames[field] else {
                    return
                }
                let getter = virtualMachine.getValue(forKey: getterName)
                guard getter.isClosure,
                      let value = getter.callConstructor(with: [instance]),
                      let converted = AnnotatedGravityValueBridge.makeEditorFieldValue(value) else {
                    return
                }
                result[field] = converted
            }
        }
    }

    func remove(instanceID: UUID) {
        lock.withLock {
            instances[instanceID] = nil
            classNamesByInstance[instanceID] = nil
        }
    }

    private func bind(
        _ bindings: [ResolvedGravityScriptableBinding],
        to instance: GSValue,
        context: ScriptableObjectContext
    ) {
        for binding in bindings {
            let propertyName: String
            let bridge: AnyObject
            switch binding {
            case let .component(name, type, descriptor, _):
                propertyName = name
                bridge = GravityAttachedComponentView.make(
                    world: context.scriptingWorld,
                    entityID: context.entityID,
                    componentType: type,
                    descriptor: descriptor,
                    reportDiagnostic: delegate.append,
                    virtualMachine: virtualMachine
                )
            case let .resource(name, type, fields, optional):
                propertyName = name
                bridge = GravityAttachedResourceView.make(
                    world: context.scriptingWorld,
                    resourceType: type,
                    fields: fields,
                    optional: optional,
                    reportDiagnostic: delegate.append,
                    virtualMachine: virtualMachine
                )
            }
            _ = instance.setStoredProperty(
                named: propertyName,
                to: GSValue(object: bridge, in: virtualMachine)
            )
        }
    }
}
