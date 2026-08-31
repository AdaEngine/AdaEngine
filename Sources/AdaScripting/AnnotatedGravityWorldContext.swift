@_spi(Scripting) import AdaECS
import Gravity

@GSExportable("AdaWorldContext")
final class AnnotatedGravityWorldContext: @unchecked Sendable {
    let commands: AnnotatedGravityCommandsBridge

    @GSExportableIgnore
    static func make(commands: AnnotatedGravityCommandsBridge) -> AnnotatedGravityWorldContext {
        AnnotatedGravityWorldContext(commands: commands)
    }

    private init(commands: AnnotatedGravityCommandsBridge) {
        self.commands = commands
    }

    func invalidate() {
        commands.invalidate()
    }
}

@GSExportable("AdaCommands")
final class AnnotatedGravityCommandsBridge: @unchecked Sendable {
    private let commands: Commands?
    private let reportDiagnostic: @Sendable (String) -> Void
    private var isActive = true

    @GSExportableIgnore
    static func make(
        commands: Commands?,
        reportDiagnostic: @escaping @Sendable (String) -> Void
    ) -> AnnotatedGravityCommandsBridge {
        AnnotatedGravityCommandsBridge(
            commands: commands,
            reportDiagnostic: reportDiagnostic
        )
    }

    private init(
        commands: Commands?,
        reportDiagnostic: @escaping @Sendable (String) -> Void
    ) {
        self.commands = commands
        self.reportDiagnostic = reportDiagnostic
    }

    func spawn(_ componentNamesValue: GSValue) -> Int {
        guard validateAccess() else {
            return -1
        }
        guard componentNamesValue.isList else {
            reportDiagnostic("commands.spawn expects a list of component names")
            return -1
        }

        var componentIDs = Set<ComponentId>()
        var components: [any Component] = []
        for nameValue in componentNamesValue.toList {
            guard nameValue.isString else {
                reportDiagnostic("commands.spawn component names must be strings")
                return -1
            }
            let name = nameValue.toString
            guard let component = RuntimeTypeRegistry.makeDefaultComponent(named: name) else {
                reportDiagnostic("Component '\(name)' does not have a registered default")
                return -1
            }
            guard componentIDs.insert(type(of: component).identifier).inserted else {
                reportDiagnostic("commands.spawn contains duplicate component '\(name)'")
                return -1
            }
            components.append(component)
        }

        guard let commands else {
            return -1
        }
        return commands.spawn(detachedComponents: components).entityId
    }

    @discardableResult
    func insert(_ entityID: Int, _ componentName: String) -> Bool {
        guard validateAccess(), let commands else {
            return false
        }
        guard let component = RuntimeTypeRegistry.makeDefaultComponent(named: componentName) else {
            reportDiagnostic("Component '\(componentName)' does not have a registered default")
            return false
        }
        commands.insert(component, into: entityID)
        return true
    }

    @discardableResult
    func remove(_ entityID: Int, _ componentName: String) -> Bool {
        guard validateAccess(), let commands else {
            return false
        }
        guard let componentType = RuntimeTypeRegistry.componentType(named: componentName) else {
            reportDiagnostic("Unknown component '\(componentName)'")
            return false
        }
        commands.entity(entityID).remove(componentType.identifier, from: entityID)
        return true
    }

    @discardableResult
    func despawn(_ entityID: Int) -> Bool {
        guard validateAccess(), let commands else {
            return false
        }
        commands.entity(entityID).removeFromWorld()
        return true
    }

    func invalidate() {
        isActive = false
    }

    private func validateAccess() -> Bool {
        guard isActive else {
            reportDiagnostic("World commands capability is no longer valid")
            return false
        }
        guard commands != nil else {
            reportDiagnostic("System did not declare deferred world command access")
            return false
        }
        return true
    }
}
