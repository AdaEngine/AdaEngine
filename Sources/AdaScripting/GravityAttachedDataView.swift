@_spi(Scripting) import AdaECS
import Gravity

@GSExportable("AdaAttachedComponent")
final class GravityAttachedComponentView: @unchecked Sendable, AdaScriptNonSendableBridge {
    /// A component is either a native Swift type or a script-declared runtime payload.
    private enum Target {
        case native(type: any Component.Type, descriptor: ReflectedComponentDescriptor?)
        case runtime(RuntimeComponentDescriptor)
    }

    private let target: Target
    private let entityID: Entity.ID
    private let reportDiagnostic: @Sendable (String) -> Void
    private let virtualMachine: GravityVirtualMachine
    // The VM may retain this bridge; it must never keep a stopped scene alive.
    // Access runs under AdaScriptRuntimeCoordinator; each use retains a local world snapshot.
    private weak var world: World?

    @GSExportableIgnore
    static func make(
        world: World,
        entityID: Entity.ID,
        componentType: any Component.Type,
        descriptor: ReflectedComponentDescriptor?,
        reportDiagnostic: @escaping @Sendable (String) -> Void,
        virtualMachine: GravityVirtualMachine
    ) -> GravityAttachedComponentView {
        GravityAttachedComponentView(
            world: world,
            entityID: entityID,
            target: .native(type: componentType, descriptor: descriptor),
            reportDiagnostic: reportDiagnostic,
            virtualMachine: virtualMachine
        )
    }

    @GSExportableIgnore
    static func make(
        world: World,
        entityID: Entity.ID,
        runtimeDescriptor: RuntimeComponentDescriptor,
        reportDiagnostic: @escaping @Sendable (String) -> Void,
        virtualMachine: GravityVirtualMachine
    ) -> GravityAttachedComponentView {
        GravityAttachedComponentView(
            world: world,
            entityID: entityID,
            target: .runtime(runtimeDescriptor),
            reportDiagnostic: reportDiagnostic,
            virtualMachine: virtualMachine
        )
    }

    private init(
        world: World,
        entityID: Entity.ID,
        target: Target,
        reportDiagnostic: @escaping @Sendable (String) -> Void,
        virtualMachine: GravityVirtualMachine
    ) {
        self.target = target
        self.entityID = entityID
        self.reportDiagnostic = reportDiagnostic
        self.virtualMachine = virtualMachine
        self.world = world
    }

    func available() -> Bool {
        switch target {
        case let .native(type, _):
            world?.has(type.identifier, in: entityID) == true
        case let .runtime(descriptor):
            world?.has(descriptor.componentID, in: entityID) == true
        }
    }

    func get(_ fieldName: String) -> GSValue? {
        guard let world, let value = readField(fieldName, in: world) else {
            reportDiagnostic("Unknown or unavailable attached component field '\(fieldName)'")
            return nil
        }
        return AnnotatedGravityValueBridge.makeGravityValue(value, virtualMachine: virtualMachine)
    }

    @discardableResult
    func set(_ fieldName: String, _ value: GSValue) -> Bool {
        guard
            let world,
            let fieldValue = AnnotatedGravityValueBridge.makeReflectedFieldValue(value),
            writeField(fieldName, fieldValue, in: world)
        else {
            reportDiagnostic("Invalid attached component field '\(fieldName)'")
            return false
        }
        return true
    }

    private func readField(_ fieldName: String, in world: World) -> ReflectedFieldValue? {
        switch target {
        case let .native(_, descriptor):
            guard
                let descriptor,
                let field = descriptor.fields.first(where: { $0.key == fieldName }),
                let component = world.getComponent(named: descriptor.typeName, from: entityID)
            else {
                return nil
            }
            return field.read(component)
        case let .runtime(descriptor):
            guard
                let field = descriptor.fields.first(where: { $0.key == fieldName }),
                let payload = world.getRuntimeComponent(descriptor.componentID, from: entityID)
            else {
                return nil
            }
            return field.read(payload)
        }
    }

    private func writeField(_ fieldName: String, _ value: ReflectedFieldValue, in world: World) -> Bool {
        switch target {
        case let .native(_, descriptor):
            return descriptor?.write(value, toField: fieldName, in: world, entity: entityID) == true
        case let .runtime(descriptor):
            guard let field = descriptor.fields.first(where: { $0.key == fieldName }) else {
                return false
            }
            return world.writeComponentField(component: descriptor.componentID, entity: entityID, field: field, value: value)
        }
    }
}

@GSExportable("AdaAttachedResource")
final class GravityAttachedResourceView: @unchecked Sendable, AdaScriptNonSendableBridge {
    private let fields: [String: ReflectedComponentField]
    private let optional: Bool
    private let reportDiagnostic: @Sendable (String) -> Void
    private let resourceType: any Resource.Type
    private let virtualMachine: GravityVirtualMachine
    // The VM may retain this bridge; it must never keep a stopped scene alive.
    // Access runs under AdaScriptRuntimeCoordinator; each use retains a local world snapshot.
    private weak var world: World?

    @GSExportableIgnore
    static func make(
        world: World,
        resourceType: any Resource.Type,
        fields: [String: ReflectedComponentField],
        optional: Bool,
        reportDiagnostic: @escaping @Sendable (String) -> Void,
        virtualMachine: GravityVirtualMachine
    ) -> GravityAttachedResourceView {
        GravityAttachedResourceView(
            world: world,
            resourceType: resourceType,
            fields: fields,
            optional: optional,
            reportDiagnostic: reportDiagnostic,
            virtualMachine: virtualMachine
        )
    }

    private init(
        world: World,
        resourceType: any Resource.Type,
        fields: [String: ReflectedComponentField],
        optional: Bool,
        reportDiagnostic: @escaping @Sendable (String) -> Void,
        virtualMachine: GravityVirtualMachine
    ) {
        self.fields = fields
        self.optional = optional
        self.reportDiagnostic = reportDiagnostic
        self.resourceType = resourceType
        self.virtualMachine = virtualMachine
        self.world = world
    }

    func available() -> Bool {
        world?.getResource(named: String(reflecting: resourceType)) != nil
    }

    func get(_ fieldName: String) -> GSValue? {
        guard
            let world, let field = fields[fieldName],
            let value = world.readResourceField(type: resourceType, field: field)
        else {
            if !optional {
                reportDiagnostic("Unknown or unavailable attached resource field '\(fieldName)'")
            }
            return nil
        }
        return AnnotatedGravityValueBridge.makeGravityValue(value, virtualMachine: virtualMachine)
    }

    @discardableResult
    func set(_ fieldName: String, _ value: GSValue) -> Bool {
        guard
            let world, let field = fields[fieldName],
            let fieldValue = AnnotatedGravityValueBridge.makeReflectedFieldValue(value),
            world.writeResourceField(type: resourceType, field: field, value: fieldValue)
        else {
            reportDiagnostic("Invalid attached resource field '\(fieldName)'")
            return false
        }
        return true
    }
}
