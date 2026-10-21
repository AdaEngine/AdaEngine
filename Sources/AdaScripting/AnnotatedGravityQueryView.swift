@_spi(Scripting) import AdaECS
import Gravity

/// Access is serialized by AdaScriptRuntimeCoordinator while a callback is active.
final class AnnotatedGravityQueryLease: @unchecked Sendable {
    var isActive = true
}

@GSExportable("AdaQuery")
final class AnnotatedGravityQueryBridge: @unchecked Sendable, AdaScriptNonSendableBridge {
    private let cursor: DynamicQueryCursor
    private let row: AnnotatedGravityQueryRow
    private let virtualMachine: GravityVirtualMachine
    private var iterationIndex = 0
    @GSExportableIgnore
    private(set) var isIterating = false
    private let lease: AnnotatedGravityQueryLease
    private let reportDiagnostic: @Sendable (String) -> Void

    @GSExportableIgnore
    static func make(
        cursor: DynamicQueryCursor,
        componentAccesses: [AnnotatedComponentAccess],
        reportDiagnostic: @escaping @Sendable (String) -> Void,
        virtualMachine: GravityVirtualMachine
    ) -> AnnotatedGravityQueryBridge {
        AnnotatedGravityQueryBridge(
            cursor: cursor,
            componentAccesses: componentAccesses,
            reportDiagnostic: reportDiagnostic,
            virtualMachine: virtualMachine
        )
    }

    private init(
        cursor: DynamicQueryCursor,
        componentAccesses: [AnnotatedComponentAccess],
        reportDiagnostic: @escaping @Sendable (String) -> Void,
        virtualMachine: GravityVirtualMachine
    ) {
        self.cursor = cursor
        self.virtualMachine = virtualMachine
        self.lease = AnnotatedGravityQueryLease()
        self.reportDiagnostic = reportDiagnostic
        self.row = AnnotatedGravityQueryRow.make(
            cursor: cursor,
            componentAccesses: componentAccesses,
            lease: lease,
            reportDiagnostic: reportDiagnostic,
            virtualMachine: virtualMachine
        )
    }

    func iterate(_ previous: GSValue) -> GSValue {
        guard lease.isActive else {
            reportDiagnostic("Query capability is no longer valid")
            return GSValue(boolean: false, in: virtualMachine)
        }
        if previous.isNull || previous.isUndefined {
            cursor.reset()
            iterationIndex = 0
        }
        guard cursor.advance() else {
            isIterating = false
            return GSValue(boolean: false, in: virtualMachine)
        }
        isIterating = true
        defer { iterationIndex += 1 }
        return GSValue(integer: iterationIndex, in: virtualMachine)
    }

    func next(_: Int) -> AnnotatedGravityQueryRow {
        row
    }

    @GSExportableIgnore
    func invalidate() {
        lease.isActive = false
        isIterating = false
    }
}

@GSExportable("AdaQueryRow")
final class AnnotatedGravityQueryRow: @unchecked Sendable, AdaScriptNonSendableBridge {
    var id: Int {
        guard lease.isActive else {
            reportDiagnostic("Query row is no longer valid")
            return -1
        }
        return cursor.entityID
    }

    private let componentViews: [String: AnnotatedGravityComponentView]
    private let cursor: DynamicQueryCursor
    private let reportDiagnostic: @Sendable (String) -> Void
    private let virtualMachine: GravityVirtualMachine
    private let lease: AnnotatedGravityQueryLease

    @GSExportableIgnore
    static func make(
        cursor: DynamicQueryCursor,
        componentAccesses: [AnnotatedComponentAccess],
        lease: AnnotatedGravityQueryLease,
        reportDiagnostic: @escaping @Sendable (String) -> Void,
        virtualMachine: GravityVirtualMachine
    ) -> AnnotatedGravityQueryRow {
        AnnotatedGravityQueryRow(
            cursor: cursor,
            componentAccesses: componentAccesses,
            lease: lease,
            reportDiagnostic: reportDiagnostic,
            virtualMachine: virtualMachine
        )
    }

    private init(
        cursor: DynamicQueryCursor,
        componentAccesses: [AnnotatedComponentAccess],
        lease: AnnotatedGravityQueryLease,
        reportDiagnostic: @escaping @Sendable (String) -> Void,
        virtualMachine: GravityVirtualMachine
    ) {
        self.cursor = cursor
        self.reportDiagnostic = reportDiagnostic
        self.virtualMachine = virtualMachine
        self.lease = lease
        self.componentViews = Dictionary(
            uniqueKeysWithValues: componentAccesses.map { access in
                (
                    access.alias,
                    AnnotatedGravityComponentView.make(
                        cursor: cursor,
                        access: access,
                        lease: lease,
                        reportDiagnostic: reportDiagnostic,
                        virtualMachine: virtualMachine
                    )
                )
            }
        )
    }

    func get(_ component: String, _ field: String) -> GSValue {
        guard lease.isActive else {
            reportDiagnostic("Query row is no longer valid")
            return GSValue(nullIn: virtualMachine)
        }
        guard let componentView = componentViews[component] else {
            reportDiagnostic("Unknown query component alias '\(component)'")
            return GSValue(nullIn: virtualMachine)
        }
        return componentView.get(field)
    }

    @discardableResult
    func set(_ component: String, _ field: String, _ value: GSValue) -> Bool {
        guard lease.isActive else {
            reportDiagnostic("Query row is no longer valid")
            return false
        }
        guard let componentView = componentViews[component] else {
            reportDiagnostic("Unknown query component alias '\(component)'")
            return false
        }
        return componentView.set(field, value)
    }

    func component(named alias: String) -> AnnotatedGravityComponentView? {
        guard lease.isActive else {
            reportDiagnostic("Query row is no longer valid")
            return nil
        }
        return componentViews[alias]
    }

    /// The row's component for `alias` as a script value: the component view, or `null` for an optional
    /// component this row does not have. `nil` when the row has no such property.
    func componentValue(named alias: String) -> GSValue? {
        guard let view = component(named: alias) else {
            return nil
        }
        return view.isPresent ? GSValue(object: view, in: virtualMachine) : GSValue(nullIn: virtualMachine)
    }
}

@GSExportable("AdaComponent")
final class AnnotatedGravityComponentView: @unchecked Sendable, AdaScriptNonSendableBridge {
    private let access: AnnotatedComponentAccess
    private let cursor: DynamicQueryCursor
    private let reportDiagnostic: @Sendable (String) -> Void
    private let virtualMachine: GravityVirtualMachine
    private let lease: AnnotatedGravityQueryLease

    @GSExportableIgnore
    static func make(
        cursor: DynamicQueryCursor,
        access: AnnotatedComponentAccess,
        lease: AnnotatedGravityQueryLease,
        reportDiagnostic: @escaping @Sendable (String) -> Void,
        virtualMachine: GravityVirtualMachine
    ) -> AnnotatedGravityComponentView {
        AnnotatedGravityComponentView(
            cursor: cursor,
            access: access,
            lease: lease,
            reportDiagnostic: reportDiagnostic,
            virtualMachine: virtualMachine
        )
    }

    private init(
        cursor: DynamicQueryCursor,
        access: AnnotatedComponentAccess,
        lease: AnnotatedGravityQueryLease,
        reportDiagnostic: @escaping @Sendable (String) -> Void,
        virtualMachine: GravityVirtualMachine
    ) {
        self.cursor = cursor
        self.access = access
        self.reportDiagnostic = reportDiagnostic
        self.virtualMachine = virtualMachine
        self.lease = lease
    }

    @GSExportableIgnore
    var isPresent: Bool { cursor.isPresent(componentAt: access.componentIndex) }

    func shader(_ slot: Int) -> GSValue {
        do {
            guard lease.isActive else { throw ShaderGraphScriptError.expired }
            let material = try ShaderGraphScriptComponent.material(cursor: cursor, index: access.componentIndex, slot: slot)
            let handle = ShaderGraphScriptHandle(material: material, writable: access.isWritable, isActive: { [lease] in lease.isActive })
            let bridge = AdaScriptShaderGraphBridge.make(handle: handle, virtualMachine: virtualMachine, reportDiagnostic: reportDiagnostic)
            return GSValue(object: bridge, in: virtualMachine)
        } catch { reportDiagnostic("ShaderGraph: \(error)"); return GSValue(nullIn: virtualMachine) }
    }

    func assignShader(_ slot: Int, _ path: String) -> Bool {
        do {
            guard lease.isActive else { throw ShaderGraphScriptError.expired }
            return try ShaderGraphScriptComponent.assign(cursor: cursor, index: access.componentIndex, slot: slot, path: path, writable: access.isWritable)
        } catch { reportDiagnostic("ShaderGraph: \(error)"); return false }
    }

    func get(_ fieldName: String) -> GSValue {
        guard lease.isActive else {
            reportDiagnostic("Component view is no longer valid")
            return GSValue(nullIn: virtualMachine)
        }
        guard
            let field = access.fields[fieldName],
            let value = cursor.read(componentAt: access.componentIndex, field: field)
        else {
            reportDiagnostic("Unknown or unreadable field '\(access.alias).\(fieldName)'")
            return GSValue(nullIn: virtualMachine)
        }
        return AnnotatedGravityValueBridge.makeGravityValue(
            value,
            virtualMachine: virtualMachine
        )
    }

    @discardableResult
    func set(_ fieldName: String, _ value: GSValue) -> Bool {
        guard lease.isActive else {
            reportDiagnostic("Component view is no longer valid")
            return false
        }
        guard let field = access.fields[fieldName] else {
            reportDiagnostic("Unknown field '\(access.alias).\(fieldName)'")
            return false
        }
        guard access.isWritable else {
            reportDiagnostic("Component '\(access.alias)' is read-only in this system; the script's access analysis found no write to it")
            return false
        }
        guard
            let fieldValue = AnnotatedGravityValueBridge.makeReflectedFieldValue(value),
            cursor.write(componentAt: access.componentIndex, field: field, value: fieldValue)
        else {
            reportDiagnostic("Invalid value for '\(access.alias).\(fieldName)'")
            return false
        }
        return true
    }
}
