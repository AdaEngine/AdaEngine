@_spi(Scripting) import AdaECS
import Gravity

/// Converts script component values into native components detached from the Gravity VM.
///
/// Both deferred commands and exclusive immediate operations share this decoder so a
/// payload is validated identically regardless of when it is applied.
struct AnnotatedGravityComponentPayloads: Sendable {
    struct Decoded {
        let value: any Component
        let name: String
    }

    private let runtimeComponents: [String: RuntimeComponentDescriptor]
    private let reportDiagnostic: @Sendable (String) -> Void

    init(runtimeComponents: [String: RuntimeComponentDescriptor], reportDiagnostic: @escaping @Sendable (String) -> Void) {
        self.runtimeComponents = runtimeComponents
        self.reportDiagnostic = reportDiagnostic
    }

    /// Decodes a list of component names or constructor values, rejecting duplicates.
    func decodeList(_ values: GSValue, operation: String) -> [any Component]? {
        guard values.isList else {
            reportDiagnostic("\(operation) expects a list of components")
            return nil
        }
        var componentIDs = Set<ComponentId>()
        var components: [any Component] = []
        for value in values.toList {
            guard let decoded = decodeComponent(value, operation: operation) else {
                return nil
            }
            let componentID = (decoded.value as? RuntimeComponentPayload)?.componentID ?? type(of: decoded.value).identifier
            guard componentIDs.insert(componentID).inserted else {
                reportDiagnostic("\(operation) contains duplicate component '\(decoded.name)'")
                return nil
            }
            components.append(decoded.value)
        }
        return components
    }

    /// Decodes one stable component name (registered default) or one constructor value.
    func decodeComponent(_ value: GSValue, operation: String) -> Decoded? {
        if value.isString {
            let name = value.toString
            guard let component = makeDefaultComponent(named: name) else {
                reportDiagnostic("Component '\(name)' does not have a registered default")
                return nil
            }
            return Decoded(value: component, name: name)
        }
        guard let constructed = value.toObjectOf(AnnotatedGravityComponentValue.self) else {
            reportDiagnostic("\(operation) values must be component constructors")
            return nil
        }
        guard let component = constructed.takeComponent() else {
            reportDiagnostic("\(operation) received an invalid or already consumed component")
            return nil
        }
        return Decoded(value: component, name: String(describing: type(of: component)))
    }

    func makeDefaultComponent(named name: String) -> (any Component)? {
        RuntimeTypeRegistry.makeDefaultComponent(named: name) ?? runtimeComponents[name]?.makeDefault()
    }

    func componentID(named name: String) -> ComponentId? {
        if let componentType = RuntimeTypeRegistry.componentType(named: name) {
            return componentType.identifier
        }
        return runtimeComponents[name]?.componentID
    }
}
