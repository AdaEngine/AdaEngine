@_spi(Scripting) import AdaECS
import AdaUtils
import Gravity

/// A script-defined event travelling through the world's native event storage.
///
/// Payload values are detached reflected values, so the event outlives the VM callback
/// that created it and can be read by a different system on the next frame.
struct AdaScriptRuntimeEvent: Event, Equatable {
    let name: String
    let fields: [String: ReflectedFieldValue]
}

/// Declares the component access a system requested through `@access`.
struct AnnotatedDeclaredAccess: SystemParameter {
    let reads: Set<ComponentId>
    let writes: Set<ComponentId>

    var access: SystemAccessSet {
        var access = SystemAccessSet()
        for component in writes { access.addComponentWrite(component) }
        for component in reads.subtracting(writes) { access.addComponentRead(component) }
        return access
    }

    init(reads: Set<ComponentId>, writes: Set<ComponentId>) {
        self.reads = reads
        self.writes = writes
    }

    init(from _: World) {
        self.init(reads: [], writes: [])
    }

    func update(from _: World) {}
    func finish(_: World) {}
}

/// One component resolved for the dynamic `@access` world API.
struct PreparedDynamicComponent: Sendable {
    let identifier: ComponentId
    let fields: [String: ReflectedComponentField]
    let isWritable: Bool
}

/// Checked dynamic component access limited to an explicit `@access` declaration.
final class AnnotatedGravityDynamicAccess: @unchecked Sendable {
    private let world: World
    private let components: [String: PreparedDynamicComponent]
    private let virtualMachine: GravityVirtualMachine
    private let reportDiagnostic: @Sendable (String) -> Void

    init(
        world: World,
        components: [String: PreparedDynamicComponent],
        virtualMachine: GravityVirtualMachine,
        reportDiagnostic: @escaping @Sendable (String) -> Void
    ) {
        self.world = world
        self.components = components
        self.virtualMachine = virtualMachine
        self.reportDiagnostic = reportDiagnostic
    }

    func has(_ entity: Int, _ component: String) -> Bool {
        guard let prepared = declared(component, writing: false) else {
            return false
        }
        return world.has(prepared.identifier, in: entity)
    }

    func read(_ entity: Int, _ component: String, _ field: String) -> GSValue {
        let null = GSValue(nullIn: virtualMachine)
        guard let prepared = declared(component, writing: false), let reflected = prepared.fields[field] else {
            if components[component] != nil { reportDiagnostic("Component '\(component)' has no field '\(field)'") }
            return null
        }
        guard let value = world.readComponentField(component: prepared.identifier, entity: entity, field: reflected) else {
            return null
        }
        return AnnotatedGravityValueBridge.makeGravityValue(value, virtualMachine: virtualMachine)
    }

    func write(_ entity: Int, _ component: String, _ field: String, _ value: GSValue) -> Bool {
        guard let prepared = declared(component, writing: true) else {
            return false
        }
        guard let reflected = prepared.fields[field] else {
            reportDiagnostic("Component '\(component)' has no field '\(field)'")
            return false
        }
        guard let converted = AnnotatedGravityValueBridge.makeReflectedFieldValue(value) else {
            reportDiagnostic("Field '\(component).\(field)' received an unsupported value")
            return false
        }
        guard world.writeComponentField(component: prepared.identifier, entity: entity, field: reflected, value: converted) else {
            reportDiagnostic("Could not write '\(component).\(field)' on entity \(entity)")
            return false
        }
        return true
    }

    private func declared(_ component: String, writing: Bool) -> PreparedDynamicComponent? {
        guard let prepared = components[component] else {
            reportDiagnostic("Component '\(component)' is not declared in this system's @access set")
            return nil
        }
        if writing, !prepared.isWritable {
            reportDiagnostic("Component '\(component)' is declared read-only in this system's @access set")
            return nil
        }
        return prepared
    }
}

/// Immediate structural operations for `@exclusiveWorld` systems.
final class AnnotatedGravityExclusiveAccess: @unchecked Sendable {
    private let world: World
    private let payloads: AnnotatedGravityComponentPayloads
    private let iterators: [AnnotatedGravityQueryBridge]
    private let reportDiagnostic: @Sendable (String) -> Void

    init(
        world: World,
        payloads: AnnotatedGravityComponentPayloads,
        iterators: [AnnotatedGravityQueryBridge],
        reportDiagnostic: @escaping @Sendable (String) -> Void
    ) {
        self.world = world
        self.payloads = payloads
        self.iterators = iterators
        self.reportDiagnostic = reportDiagnostic
    }

    func spawn(_ values: GSValue) -> Int {
        guard canMutate("spawnImmediate"), let components = payloads.decodeList(values, operation: "world.spawnImmediate") else {
            return -1
        }
        return world.spawn(detachedComponents: components).id
    }

    func insert(_ entity: Int, _ value: GSValue) -> Bool {
        guard canMutate("insertImmediate"), requireEntity(entity, "insertImmediate"),
            let component = payloads.decodeComponent(value, operation: "world.insertImmediate") else {
            return false
        }
        world.insert(detachedComponent: component.value, for: entity)
        return true
    }

    func remove(_ entity: Int, _ name: String) -> Bool {
        guard canMutate("removeImmediate"), requireEntity(entity, "removeImmediate") else {
            return false
        }
        guard let componentID = payloads.componentID(named: name) else {
            reportDiagnostic("Unknown component '\(name)'")
            return false
        }
        world.remove(componentID, from: entity)
        return true
    }

    func despawn(_ entity: Int) -> Bool {
        guard canMutate("despawnImmediate"), requireEntity(entity, "despawnImmediate") else {
            return false
        }
        world.removeEntity(entity)
        return true
    }

    private func requireEntity(_ entity: Int, _ operation: String) -> Bool {
        guard world.getEntityByID(entity) != nil else {
            reportDiagnostic("world.\(operation) received unknown entity \(entity)")
            return false
        }
        return true
    }

    private func canMutate(_ operation: String) -> Bool {
        guard !iterators.contains(where: \.isIterating) else {
            reportDiagnostic("world.\(operation) cannot run while a query iterator is active")
            return false
        }
        return true
    }
}
