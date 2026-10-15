import AdaScriptCompilerCore

/// Diagnostics for ADR-0004 world capabilities: declaration placement, declared-access
/// checks, and retained-capability lifetime violations.
///
/// Annotations and `context.world` uses come from the shared syntax tree, the same facts the compiler reads.
enum GravityCapabilityAnalyzer {
    private static let immediateOperations: Set<String> = ["spawnImmediate", "insertImmediate", "removeImmediate", "despawnImmediate"]
    private static let dynamicOperations: Set<String> = ["read", "write", "has"]
    private static let systemOnlyAnnotations: Set<String> = ["access", "exclusiveWorld"]
    private static let eventAnnotations: Set<String> = ["events", "eventWriter"]

    static func diagnostics(regions: [GravityTypeRegion], globals: Set<String>, syntax: AdaScriptSyntaxTree) -> [GravityDiagnostic] {
        var diagnostics = placementDiagnostics(regions: regions, syntax: syntax)
        for region in regions where region.annotations.contains("system") {
            diagnostics += bodyDiagnostics(region: region, globals: globals, syntax: syntax)
        }
        return diagnostics
    }

    // MARK: Placement

    private static func placementDiagnostics(regions: [GravityTypeRegion], syntax: AdaScriptSyntaxTree) -> [GravityDiagnostic] {
        var diagnostics: [GravityDiagnostic] = []
        for region in regions where !region.annotations.contains("system") {
            for annotation in region.annotationSyntaxes where systemOnlyAnnotations.contains(annotation.name) {
                diagnostics.append(GravityDiagnostic(message: "@\(annotation.name) can only annotate an @system class", range: annotation.nameRange.gravityRange))
            }
        }
        for annotation in syntax.annotations where eventAnnotations.contains(annotation.name) {
            let start = gravityPosition(annotation.range.start)
            guard let owner = regions.first(where: { region in
                region.bodyStart < start && start < region.bodyEnd
            }), owner.annotations.contains("system") else {
                diagnostics.append(
                    GravityDiagnostic(
                        message: "@\(annotation.name) must annotate a stored property inside an @system class",
                        range: annotation.nameRange.gravityRange
                    )
                )
                continue
            }
            if !hasSingleEventName(annotation) {
                diagnostics.append(GravityDiagnostic(message: "@\(annotation.name) requires exactly one event name", range: annotation.nameRange.gravityRange))
            }
        }
        return diagnostics
    }

    /// `@events(Name)` or `@events("Name")`: one unlabelled bare or quoted name.
    private static func hasSingleEventName(_ annotation: AdaScriptAnnotationSyntax) -> Bool {
        guard annotation.problem == nil, annotation.values.count == 1, annotation.values[0].label == nil else {
            return false
        }
        switch annotation.values[0].value {
        case let .identifier(name):
            return !name.contains(".") && !name.contains(" ")
        case .string:
            return true
        case .bool, .list, .number:
            return false
        }
    }

    // MARK: Usage

    private static func bodyDiagnostics(region: GravityTypeRegion, globals: Set<String>, syntax: AdaScriptSyntaxTree) -> [GravityDiagnostic] {
        let annotations = region.annotationSyntaxes
        let isExclusive = annotations.contains { $0.name == "exclusiveWorld" }
        let access = annotations.first { $0.name == "access" }.map(accessSets)
        let properties = Set(region.symbol.members.filter { $0.kind == .property }.map(\.name))
        var diagnostics: [GravityDiagnostic] = []
        for use in syntax.worldUses {
            let start = gravityPosition(use.range.start)
            guard region.bodyStart < start, start < region.bodyEnd else {
                continue
            }
            if let member = use.member, let memberRange = use.memberRange?.gravityRange {
                if immediateOperations.contains(member), !isExclusive {
                    diagnostics.append(GravityDiagnostic(message: "world.\(member) requires @exclusiveWorld on the system", range: memberRange))
                } else if dynamicOperations.contains(member) {
                    diagnostics += dynamicAccessDiagnostics(member: member, range: memberRange, argument: use.secondArgument, access: access)
                }
            }
            if let assignment = use.assignment, isRetained(assignment, properties: properties, globals: globals) {
                diagnostics.append(GravityDiagnostic(
                    message: "context.world is only valid during the lifecycle callback; do not store it in '\(assignment.name)'",
                    range: assignment.nameRange.gravityRange
                ))
            }
        }
        return diagnostics
    }

    private static func dynamicAccessDiagnostics(
        member: String,
        range: GravitySourceRange,
        argument: AdaScriptWorldUse.Argument?,
        access: (read: Set<String>, write: Set<String>)?
    ) -> [GravityDiagnostic] {
        guard let access else {
            return [GravityDiagnostic(message: "world.\(member) requires an explicit @access declaration on the system", range: range)]
        }
        guard let argument, argument.isString else {
            return []
        }
        let component = argument.text
        let isWrite = member == "write"
        if isWrite, !access.write.contains(component) {
            let message = access.read.contains(component)
                ? "'\(component)' is declared read-only in @access"
                : "'\(component)' is not declared in @access(write:)"
            return [GravityDiagnostic(message: message, range: argument.range.gravityRange)]
        }
        if !isWrite, !access.read.contains(component), !access.write.contains(component) {
            return [GravityDiagnostic(message: "'\(component)' is not declared in @access", range: argument.range.gravityRange)]
        }
        return []
    }

    /// `name = context.world[.commands]` where `name` is a system property or a global.
    private static func isRetained(_ assignment: AdaScriptWorldUse.Assignment, properties: Set<String>, globals: Set<String>) -> Bool {
        switch assignment.qualifier {
        case .declaration, .otherMember:
            false
        case .selfMember:
            properties.contains(assignment.name)
        case .bare:
            properties.contains(assignment.name) || globals.contains(assignment.name)
        }
    }

    // MARK: Helpers

    private static func gravityPosition(_ position: AdaScriptSourcePosition) -> GravitySourcePosition {
        GravitySourcePosition(line: position.line, utf16Column: position.utf16Column)
    }

    /// The components named by `@access(read: [...], write: [...])`, from the shared annotation values.
    /// A qualified `Game.Health` counts as both `Game.Health` and `Health`.
    private static func accessSets(for annotation: AdaScriptAnnotationSyntax) -> (read: Set<String>, write: Set<String>) {
        func names(_ label: String) -> Set<String> {
            var result: Set<String> = []
            func collect(_ value: AdaScriptAnnotationValue) {
                switch value {
                case let .identifier(name), let .string(name):
                    result.insert(name)
                    if let short = name.split(separator: ".").last {
                        result.insert(String(short))
                    }
                case let .list(values):
                    values.forEach(collect)
                case .bool, .number:
                    break
                }
            }
            annotation.values.filter { $0.label == label }.forEach { collect($0.value) }
            return result
        }
        return (names("read"), names("write"))
    }
}
