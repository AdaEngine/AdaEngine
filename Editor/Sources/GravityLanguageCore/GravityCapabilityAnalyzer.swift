/// Diagnostics for ADR-0004 world capabilities: declaration placement, declared-access
/// checks, and retained-capability lifetime violations.
enum GravityCapabilityAnalyzer {
    private static let immediateOperations: Set<String> = ["spawnImmediate", "insertImmediate", "removeImmediate", "despawnImmediate"]
    private static let dynamicOperations: Set<String> = ["read", "write", "has"]
    private static let systemOnlyAnnotations: Set<String> = ["access", "exclusiveWorld"]
    private static let eventAnnotations: Set<String> = ["events", "eventWriter"]

    static func diagnostics(regions: [GravityTypeRegion], tokens: [GravityToken], globals: Set<String>) -> [GravityDiagnostic] {
        var diagnostics = placementDiagnostics(regions: regions, tokens: tokens)
        for region in regions where region.annotations.contains("system") {
            diagnostics += bodyDiagnostics(region: region, tokens: tokens, globals: globals)
        }
        return diagnostics
    }

    // MARK: Placement

    private static func placementDiagnostics(regions: [GravityTypeRegion], tokens: [GravityToken]) -> [GravityDiagnostic] {
        var diagnostics: [GravityDiagnostic] = []
        for region in regions where !region.annotations.contains("system") {
            guard let declarationIndex = tokens.firstIndex(where: { $0.range.start == region.symbol.range.start }) else {
                continue
            }
            for annotation in GravityDocumentAnalyzer.annotationTokens(before: declarationIndex, in: tokens)
            where systemOnlyAnnotations.contains(annotation.text) {
                diagnostics.append(GravityDiagnostic(message: "@\(annotation.text) can only annotate an @system class", range: annotation.range))
            }
        }
        for index in tokens.indices where index > 0 && tokens[index - 1].text == "@" && eventAnnotations.contains(tokens[index].text) {
            let annotation = tokens[index]
            guard let owner = regions.first(where: { region in
                region.openBraceIndex < index && index < region.closeBraceIndex
            }), owner.annotations.contains("system") else {
                diagnostics.append(GravityDiagnostic(message: "@\(annotation.text) must annotate a stored property inside an @system class", range: annotation.range))
                continue
            }
            let arguments = argumentTokens(after: index, in: tokens)
            if arguments.count != 1 || ![.identifier, .string].contains(arguments[0].kind) {
                diagnostics.append(GravityDiagnostic(message: "@\(annotation.text) requires exactly one event name", range: annotation.range))
            }
        }
        return diagnostics
    }

    // MARK: Usage

    private static func bodyDiagnostics(region: GravityTypeRegion, tokens: [GravityToken], globals: Set<String>) -> [GravityDiagnostic] {
        guard let declarationIndex = tokens.firstIndex(where: { $0.range.start == region.symbol.range.start }) else {
            return []
        }
        let annotations = GravityDocumentAnalyzer.annotationTokens(before: declarationIndex, in: tokens)
        let isExclusive = annotations.contains { $0.text == "exclusiveWorld" }
        let access = annotations.first { $0.text == "access" }.map { accessSets(for: $0, in: tokens) }
        let properties = Set(region.symbol.members.filter { $0.kind == .property }.map(\.name))
        var diagnostics: [GravityDiagnostic] = []
        let body = (region.openBraceIndex + 1)..<region.closeBraceIndex
        for index in body {
            if let member = worldMember(at: index, in: tokens) {
                if immediateOperations.contains(member.text), !isExclusive {
                    diagnostics.append(GravityDiagnostic(message: "world.\(member.text) requires @exclusiveWorld on the system", range: member.range))
                } else if dynamicOperations.contains(member.text) {
                    diagnostics += dynamicAccessDiagnostics(member: member, at: index, access: access, tokens: tokens)
                }
            }
            if let retained = retainedCapability(at: index, in: tokens, properties: properties, globals: globals) {
                diagnostics.append(GravityDiagnostic(
                    message: "context.world is only valid during the lifecycle callback; do not store it in '\(retained.text)'",
                    range: retained.range
                ))
            }
        }
        return diagnostics
    }

    private static func dynamicAccessDiagnostics(
        member: GravityToken,
        at index: Int,
        access: (read: Set<String>, write: Set<String>)?,
        tokens: [GravityToken]
    ) -> [GravityDiagnostic] {
        guard let access else {
            return [GravityDiagnostic(message: "world.\(member.text) requires an explicit @access declaration on the system", range: member.range)]
        }
        guard let name = secondArgument(afterMember: index, in: tokens), name.kind == .string else {
            return []
        }
        let component = unquoted(name.text)
        let isWrite = member.text == "write"
        if isWrite, !access.write.contains(component) {
            let message = access.read.contains(component)
                ? "'\(component)' is declared read-only in @access"
                : "'\(component)' is not declared in @access(write:)"
            return [GravityDiagnostic(message: message, range: name.range)]
        }
        if !isWrite, !access.read.contains(component), !access.write.contains(component) {
            return [GravityDiagnostic(message: "'\(component)' is not declared in @access", range: name.range)]
        }
        return []
    }

    /// Matches `context . world . <member>` and returns the member token.
    private static func worldMember(at index: Int, in tokens: [GravityToken]) -> GravityToken? {
        guard index >= 4, tokens[index - 1].text == ".", tokens[index - 2].text == "world", tokens[index - 3].text == ".", tokens[index - 4].text == "context",
            tokens[index].kind == .identifier else {
            return nil
        }
        return tokens[index]
    }

    /// Matches `name = context.world[.commands]` where `name` is a system property or a global.
    private static func retainedCapability(
        at index: Int,
        in tokens: [GravityToken],
        properties: Set<String>,
        globals: Set<String>
    ) -> GravityToken? {
        guard index + 4 < tokens.count, tokens[index].kind == .identifier, tokens[index + 1].text == "=",
            tokens[index + 2].text == "context", tokens[index + 3].text == ".", tokens[index + 4].text == "world" else {
            return nil
        }
        if index > 0, ["var", "const"].contains(tokens[index - 1].text) {
            return nil
        }
        let isMemberAssignment = index >= 2 && tokens[index - 1].text == "." && tokens[index - 2].text == "self"
        let isBareAssignment = index == 0 || tokens[index - 1].text != "."
        guard (isMemberAssignment && properties.contains(tokens[index].text))
            || (isBareAssignment && (properties.contains(tokens[index].text) || globals.contains(tokens[index].text))) else {
            return nil
        }
        return tokens[index]
    }

    // MARK: Token helpers

    private static func accessSets(for annotation: GravityToken, in tokens: [GravityToken]) -> (read: Set<String>, write: Set<String>) {
        guard let index = tokens.firstIndex(where: { $0.range == annotation.range }) else {
            return ([], [])
        }
        var sets: [String: Set<String>] = ["read": [], "write": []]
        var current: String?
        for token in argumentTokens(after: index, in: tokens) {
            if token.kind == .identifier, sets[token.text] != nil {
                current = token.text
            } else if let label = current, token.kind == .identifier || token.kind == .string {
                sets[label, default: []].insert(unquoted(token.text))
            }
        }
        return (sets["read"] ?? [], sets["write"] ?? [])
    }

    /// Tokens inside the parentheses that follow an annotation name, excluding punctuation.
    private static func argumentTokens(after nameIndex: Int, in tokens: [GravityToken]) -> [GravityToken] {
        let open = nameIndex + 1
        guard open < tokens.count, tokens[open].text == "(" else {
            return []
        }
        var depth = 0
        var result: [GravityToken] = []
        for index in open..<tokens.count {
            let token = tokens[index]
            if token.text == "(" {
                depth += 1
            } else if token.text == ")" {
                depth -= 1
                if depth == 0 { break }
            } else if token.kind != .punctuation {
                result.append(token)
            }
        }
        return result
    }

    /// The token following the first top-level comma of the call whose callee is at `memberIndex`.
    private static func secondArgument(afterMember memberIndex: Int, in tokens: [GravityToken]) -> GravityToken? {
        let open = memberIndex + 1
        guard open < tokens.count, tokens[open].text == "(" else {
            return nil
        }
        var depth = 0
        for index in open..<tokens.count {
            switch tokens[index].text {
            case "(", "[": depth += 1
            case ")", "]":
                depth -= 1
                if depth == 0 { return nil }
            case "," where depth == 1:
                return index + 1 < tokens.count ? tokens[index + 1] : nil
            default: break
            }
        }
        return nil
    }

    private static func unquoted(_ text: String) -> String {
        text.count >= 2 && text.hasPrefix("\"") && text.hasSuffix("\"") ? String(text.dropFirst().dropLast()) : text
    }
}
