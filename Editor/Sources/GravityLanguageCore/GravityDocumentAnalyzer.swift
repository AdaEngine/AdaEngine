import AdaScriptCompilerCore
import Foundation

struct GravityParsedDocument: Sendable {
    var analysis: GravityDocumentAnalysis
    var inferredTypes: [String: String]
    /// The analyzer's structured types, for the cases a display name loses information (query rows).
    var structuredTypes: [String: AdaScriptType]
    var tokens: [GravityToken]
    var typeRegions: [GravityTypeRegion]
}

struct GravityTypeRegion: Sendable {
    /// Annotations written before the type keyword, from the shared syntax tree.
    var annotationSyntaxes: [AdaScriptAnnotationSyntax]
    /// The start of the closing brace, or of the last token when the body is never closed.
    var bodyEnd: GravitySourcePosition
    /// The start of the opening brace.
    var bodyStart: GravitySourcePosition
    var implicitTypes: [String: String]
    /// Selection ranges of the members declared `static`.
    var staticMembers: Set<GravitySourceRange>
    var symbol: GravitySymbol

    var annotations: Set<String> {
        Set(annotationSyntaxes.map(\.name))
    }
}

struct GravityDocumentAnalyzer {
    static func parse(_ text: String, projectTypeChecking: AdaScriptTypeCheckingMode = .dynamic) -> GravityParsedDocument {
        var lexer = GravityLexer(source: text)
        let lexResult = lexer.lex()
        let tokens = lexResult.tokens.filter { $0.kind != .comment }
        let sharedAnalysis = AdaScriptAnalyzer.analyze(source: text)
        let syntax = sharedAnalysis.syntax
        let sharedInferredTypes = sharedAnalysis.inferredTypes.mapValues(\.displayName)
        let typeRegions = syntax.outline.types.map { typeRegion(for: $0, inferredTypes: sharedInferredTypes) }
        let symbols = globalSymbols(syntax.outline, typeRegions: typeRegions)
        let parsedImports = (diagnostics: syntax.importDiagnostics.map { GravityDiagnostic(message: $0.message, range: $0.range.gravityRange) }, imports: syntax.imports.map(\.gravityImport))
        let typeDiagnostics = sharedAnalysis.typeIssues
            .filter { _ in projectTypeChecking == .strict || syntax.isStrict }
            .map(gravityDiagnostic)
        let globals = Set(symbols.filter { [.variable, .constant].contains($0.kind) }.map(\.name))
        let capabilityDiagnostics = GravityCapabilityAnalyzer.diagnostics(regions: typeRegions, globals: globals, syntax: syntax)
        return GravityParsedDocument(
            analysis: GravityDocumentAnalysis(
                diagnostics: lexResult.diagnostics + parsedImports.diagnostics
                    + duplicatePropertyDiagnostics(typeRegions)
                    + declarationAnnotationDiagnostics(typeRegions)
                    + catalogAnnotationDiagnostics(syntax.annotationUses)
                    + capabilityDiagnostics
                    + typeDiagnostics,
                imports: parsedImports.imports,
                symbols: symbols
            ),
            inferredTypes: sharedInferredTypes,
            structuredTypes: sharedAnalysis.inferredTypes,
            tokens: lexResult.tokens,
            typeRegions: typeRegions
        )
    }

    static func typeContaining(_ position: GravitySourcePosition, in regions: [GravityTypeRegion]) -> GravitySymbol? {
        regions.first { region in
            region.symbol.range.start <= position && position <= region.symbol.range.end
        }?
        .symbol
    }

    private static func duplicatePropertyDiagnostics(_ regions: [GravityTypeRegion]) -> [GravityDiagnostic] {
        regions.flatMap { region in
            var names: Set<String> = []
            return region.symbol.members.compactMap { member -> GravityDiagnostic? in
                let key = region.staticMembers.contains(member.selectionRange) ? "$\(member.name)" : member.name
                guard member.kind == .property, !names.insert(key).inserted else {
                    return nil
                }
                return GravityDiagnostic(
                    message: "Duplicate property '\(member.name)' in '\(region.symbol.name)'",
                    range: member.selectionRange
                )
            }
        }
    }

    /// Annotations the shared catalog rejects that `declarationAnnotationDiagnostics` does not already explain
    /// with a quick-fixable message: unknown names, and misplaced annotations outside the type-kind checks.
    private static func catalogAnnotationDiagnostics(_ uses: [AdaScriptAnnotationUse]) -> [GravityDiagnostic] {
        let explainedElsewhere: Set<String> = [
            "component", "replicated_component", "resource", "network_command", "system", "scriptable", "tool", "view", "previewable",
        ]
        return AdaScriptAnnotationCatalog.problems(in: uses).compactMap { problem in
            if problem.kind == .unsupportedTarget, explainedElsewhere.contains(problem.use.name),
                [.class, .struct, .enum].contains(problem.use.target) {
                return nil
            }
            return GravityDiagnostic(message: problem.message, range: problem.use.range.gravityRange)
        }
    }

    private static func declarationAnnotationDiagnostics(_ regions: [GravityTypeRegion]) -> [GravityDiagnostic] {
        regions.flatMap { region -> [GravityDiagnostic] in
            let annotations = region.annotationSyntaxes
            let names = Set(annotations.map(\.name))
            var diagnostics = annotations.compactMap { annotation -> GravityDiagnostic? in
                let range = annotation.nameRange.gravityRange
                let requiredKind: String?
                switch annotation.name {
                case "view":
                    return GravityDiagnostic(message: "AdaUI views in AdaScript are temporarily unavailable.", range: range)
                case "previewable":
                    return GravityDiagnostic(message: "AdaUI previews in AdaScript are temporarily unavailable.", range: range)
                case "component", "replicated_component", "resource", "network_command":
                    requiredKind = "struct"
                case "system", "scriptable", "tool":
                    requiredKind = "class"
                case "previewable" where !names.contains("view"):
                    return GravityDiagnostic(message: "@previewable requires @view", range: range)
                default:
                    requiredKind = nil
                }
                guard let requiredKind, region.symbol.kind != (requiredKind == "class" ? .class : .struct) else {
                    return nil
                }
                return GravityDiagnostic(
                    message: "@\(annotation.name) requires a \(requiredKind); change '\(kindDescription(region.symbol.kind))' to '\(requiredKind)'",
                    range: range
                )
            }
            let declarationAnnotations = annotations.filter {
                ["component", "replicated_component", "resource", "network_command", "system", "scriptable", "tool"].contains($0.name)
            }
            if let first = declarationAnnotations.first {
                diagnostics += declarationAnnotations.dropFirst().map { annotation in
                    GravityDiagnostic(
                        message: "@\(annotation.name) cannot be combined with @\(first.name) on \(region.symbol.name)",
                        range: annotation.nameRange.gravityRange
                    )
                }
            }
            return diagnostics
        }
    }

    // MARK: Outline

    private static func typeRegion(for type: AdaScriptOutlineType, inferredTypes: [String: String]) -> GravityTypeRegion {
        GravityTypeRegion(
            annotationSyntaxes: type.annotations,
            bodyEnd: GravitySourcePosition(line: type.bodyEnd.line, utf16Column: type.bodyEnd.utf16Column),
            bodyStart: GravitySourcePosition(line: type.bodyStart.line, utf16Column: type.bodyStart.utf16Column),
            implicitTypes: inferredTypes,
            staticMembers: Set(type.symbol.members.filter(\.isStatic).map { $0.selectionRange.gravityRange }),
            symbol: gravitySymbol(type.symbol)
        )
    }

    private static func globalSymbols(_ outline: AdaScriptOutline, typeRegions: [GravityTypeRegion]) -> [GravitySymbol] {
        let symbols = typeRegions.map(\.symbol) + outline.globals.map(gravitySymbol)
        return symbols.uniqued(on: { "\($0.kind.rawValue):\($0.name)" })
    }

    private static func gravitySymbol(_ symbol: AdaScriptOutlineSymbol) -> GravitySymbol {
        let kind: GravitySymbolKind
        let detail: String
        switch symbol.kind {
        case .class, .enum, .struct:
            kind = symbol.kind == .class ? .class : (symbol.kind == .enum ? .enum : .struct)
            detail = "AdaScript \(kindDescription(kind))"
        case .function:
            kind = .function
            detail = symbol.isAsync ? "AdaScript async function" : "AdaScript function"
        case .method:
            kind = .method
            detail = symbol.isAsync ? "AdaScript async method" : "AdaScript method"
        case .variable:
            kind = .variable
            detail = "AdaScript variable"
        case .constant:
            kind = .constant
            detail = "AdaScript constant"
        case .property:
            kind = .property
            detail = "AdaScript property"
        }
        return GravitySymbol(
            name: symbol.name,
            kind: kind,
            detail: detail,
            range: symbol.range.gravityRange,
            selectionRange: symbol.selectionRange.gravityRange,
            members: symbol.members.map(gravitySymbol)
        )
    }

    private static func gravityDiagnostic(_ issue: AdaScriptTypeIssue) -> GravityDiagnostic {
        GravityDiagnostic(
            message: issue.message,
            range: GravitySourceRange(
                start: GravitySourcePosition(
                    line: issue.range.start.line,
                    utf16Column: issue.range.start.utf16Column
                ),
                end: GravitySourcePosition(
                    line: issue.range.end.line,
                    utf16Column: issue.range.end.utf16Column
                )
            )
        )
    }

    private static func kindDescription(_ kind: GravitySymbolKind) -> String {
        switch kind {
        case .class: "class"
        case .enum: "enum"
        case .struct: "struct"
        default: "type"
        }
    }
}

extension Sequence {
    func uniqued<Key: Hashable>(on key: (Element) -> Key) -> [Element] {
        var seen: Set<Key> = []
        return filter { seen.insert(key($0)).inserted }
    }
}
