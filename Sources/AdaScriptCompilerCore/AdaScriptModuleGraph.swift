import Foundation

/// Failures of module path resolution and graph construction.
public enum AdaScriptModuleError: Error, Equatable, Sendable {
    case duplicateSourcePath(String)
    case importCycle([String])
    case invalidImport(source: String, message: String)
    case invalidSourcePath(String)
    case unresolvedImport(source: String, importPath: String)
}

/// The path rules every consumer of imports follows: the runtime resolver, the build generator,
/// and the Editor language service resolve through these functions.
public enum AdaScriptModulePaths {
    /// Built-in modules that are not backed by a source file.
    public static let virtualModules: Set<String> = ["AdaEngine", "AdaUI"]

    public enum ResolvedImport: Equatable, Sendable {
        case source(String)
        case virtual(String)
    }

    /// Normalizes a target-relative source path, rejecting absolute and escaping paths.
    public static func canonicalSourcePath(_ path: String) throws(AdaScriptModuleError) -> String {
        try canonicalPath(path, baseComponents: [])
    }

    /// Resolves an import written in `sourcePath` to a canonical source path or a virtual module.
    public static func resolveImport(_ importPath: String, from sourcePath: String) throws(AdaScriptModuleError) -> ResolvedImport {
        if virtualModules.contains(importPath) {
            return .virtual(importPath)
        }
        if importPath.hasPrefix("@") {
            let parts = importPath.dropFirst().split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2, AdaScriptLibraryManifest.isIdentifier(String(parts[0])) else {
                throw .invalidImport(source: sourcePath, message: "library imports use @library.id/path")
            }
            var path = String(parts[1])
            if URL(fileURLWithPath: path).pathExtension.isEmpty {
                path += ".ada"
            }
            guard AdaScriptLibraryManifest.isSourcePath(path) else {
                throw .invalidImport(source: sourcePath, message: "invalid library source path")
            }
            return .source("Libraries/\(parts[0])/\(path)")
        }
        guard importPath.hasPrefix("./") || importPath.hasPrefix("../") else {
            throw .invalidImport(
                source: sourcePath,
                message: "imports must be relative or name a supported virtual module: '\(importPath)'"
            )
        }
        var baseComponents = sourcePath.split(separator: "/").map(String.init)
        _ = baseComponents.popLast()
        var resolved = try canonicalPath(importPath, baseComponents: baseComponents)
        if URL(fileURLWithPath: resolved).pathExtension.isEmpty {
            resolved += ".ada"
        }
        return .source(resolved)
    }

    private static func canonicalPath(_ path: String, baseComponents: [String]) throws(AdaScriptModuleError) -> String {
        let normalizedSeparators = path.replacingOccurrences(of: "\\", with: "/")
        guard
            !normalizedSeparators.isEmpty,
            !normalizedSeparators.hasPrefix("/"),
            !isWindowsAbsolutePath(normalizedSeparators),
            !normalizedSeparators.contains("\"")
        else {
            throw .invalidSourcePath(path)
        }
        var components = baseComponents
        for component in normalizedSeparators.split(separator: "/", omittingEmptySubsequences: false) {
            switch component {
            case "", ".":
                continue
            case "..":
                guard !components.isEmpty else {
                    throw .invalidSourcePath(path)
                }
                components.removeLast()
            default:
                components.append(String(component))
            }
        }
        guard !components.isEmpty else {
            throw .invalidSourcePath(path)
        }
        return components.joined(separator: "/")
    }

    private static func isWindowsAbsolutePath(_ path: String) -> Bool {
        let scalars = Array(path.unicodeScalars)
        return scalars.count >= 2 && scalars[1] == ":"
    }
}

/// Import ordering shared by every consumer: depth-first, dependencies before dependents, with
/// the complete cycle reported when one exists.
public enum AdaScriptModuleOrdering {
    public static func order(roots: [String], edges: [String: [String]]) throws(AdaScriptModuleError) -> [String] {
        enum State { case visiting, visited }
        var states: [String: State] = [:]
        var stack: [String] = []
        var ordered: [String] = []

        func visit(_ path: String) throws(AdaScriptModuleError) {
            switch states[path] {
            case .visited:
                return
            case .visiting:
                let start = stack.firstIndex(of: path) ?? stack.startIndex
                throw .importCycle(Array(stack[start...]) + [path])
            case nil:
                break
            }
            guard let targets = edges[path] else {
                return
            }
            states[path] = .visiting
            stack.append(path)
            defer { _ = stack.popLast() }
            for target in targets {
                try visit(target)
            }
            states[path] = .visited
            ordered.append(path)
        }

        for root in roots {
            try visit(root)
        }
        return ordered
    }

    /// Every distinct cycle reachable in `edges`, each closed (first path repeated last).
    /// The Editor reports all of them; the runtime stops at the first.
    public static func cycles(edges: [String: [String]]) -> [[String]] {
        var found: [[String]] = []
        var seen = Set<[String]>()
        var finished = Set<String>()
        var stack: [String] = []
        var onStack = Set<String>()

        func visit(_ path: String) {
            if onStack.contains(path) {
                guard let start = stack.firstIndex(of: path) else { return }
                let cycle = Array(stack[start...])
                // Rotate so the lexicographically smallest member leads, so the same cycle found
                // from different entry points is recorded once.
                let pivot = cycle.indices.min { cycle[$0] < cycle[$1] } ?? 0
                let normalized = Array(cycle[pivot...] + cycle[..<pivot])
                if seen.insert(normalized).inserted {
                    found.append(normalized + [normalized[0]])
                }
                return
            }
            guard finished.insert(path).inserted else { return }
            onStack.insert(path)
            stack.append(path)
            for target in edges[path] ?? [] { visit(target) }
            stack.removeLast()
            onStack.remove(path)
        }
        for path in edges.keys.sorted() { visit(path) }
        return found
    }
}

/// A positioned problem found while analysing how modules use each other.
public struct AdaScriptModuleDiagnostic: Equatable, Hashable, Sendable {
    public var message: String
    public var path: String
    public var range: AdaScriptSourceRange

    public init(message: String, path: String, range: AdaScriptSourceRange) {
        self.message = message
        self.path = path
        self.range = range
    }
}

/// Imports and exported declarations of a set of sources, parsed once.
public struct AdaScriptModuleGraph: Sendable {
    public struct Module: Sendable {
        public let path: String
        public let tree: AdaScriptSyntaxTree
    }

    public let modules: [String: Module]

    /// - Throws: `duplicateSourcePath` / `invalidSourcePath` for source paths that cannot form a module identity.
    public init(sources: [AdaScriptCompilerSource]) throws(AdaScriptModuleError) {
        var modules: [String: Module] = [:]
        for source in sources {
            let path = try AdaScriptModulePaths.canonicalSourcePath(source.path)
            guard modules[path] == nil else {
                throw .duplicateSourcePath(path)
            }
            modules[path] = Module(path: path, tree: AdaScriptSyntaxParser(source: source.source, path: path).parse().syntax)
        }
        self.modules = modules
    }

    public var sortedPaths: [String] { modules.keys.sorted() }

    /// A module's resolved imports, in source order. Virtual modules do not appear.
    public func dependencies(of path: String) throws(AdaScriptModuleError) -> [String] {
        guard let module = modules[path] else { return [] }
        var result: [String] = []
        for declaration in module.tree.imports {
            guard case let .source(resolved) = try AdaScriptModulePaths.resolveImport(declaration.path, from: path) else {
                continue
            }
            guard modules[resolved] != nil else {
                throw .unresolvedImport(source: path, importPath: declaration.path)
            }
            result.append(resolved)
        }
        return result
    }

    public func edges() throws(AdaScriptModuleError) -> [String: [String]] {
        var result: [String: [String]] = [:]
        for path in sortedPaths {
            result[path] = try dependencies(of: path)
        }
        return result
    }

    /// Dependencies first, the way the runtime includes modules.
    public func order(roots: [String]) throws(AdaScriptModuleError) -> [String] {
        try AdaScriptModuleOrdering.order(roots: roots, edges: edges())
    }

    /// Top-level declarations of `path` by name.
    public func declarations(in path: String) -> [String: AdaScriptDeclarationVisibility] {
        guard let tree = modules[path]?.tree else { return [:] }
        var result: [String: AdaScriptDeclarationVisibility] = [:]
        for type in tree.types { result[type.name] = type.visibility }
        for function in tree.functions { result[function.name] = function.visibility }
        for binding in tree.bindings { result[binding.name] = binding.visibility }
        return result
    }

    /// Annotations whose declarations are discovered by name, so they need no import.
    static let discoveryRootAnnotations: Set<String> = [
        "component", "network_command", "replicated_component", "resource", "scriptable", "system", "test", "tool", "view",
    ]

    /// Top-level declarations other modules must import before use: everything except discovery roots,
    /// which the engine finds by name.
    func helperDeclarations(in path: String) -> Set<String> {
        guard let tree = modules[path]?.tree else { return [] }
        var names = Set<String>()
        for type in tree.types where !type.annotations.contains(where: { Self.discoveryRootAnnotations.contains($0.name) }) {
            names.insert(type.name)
        }
        for function in tree.functions { names.insert(function.name) }
        for binding in tree.bindings { names.insert(binding.name) }
        return names
    }

    /// Import problems that do not stop compilation outright: unknown or private names, namespace
    /// members that are not exported, clashing local names, and duplicate declarations.
    ///
    /// - Parameter scope: Limit the analysis, including the duplicate check, to these modules. An editor
    ///   that holds unrelated files in one workspace passes the importing file's reachable set.
    public func semanticDiagnostics(scope: Set<String>? = nil) -> [AdaScriptModuleDiagnostic] {
        var diagnostics: [AdaScriptModuleDiagnostic] = []
        for path in sortedPaths where scope?.contains(path) ?? true {
            guard let tree = modules[path]?.tree else { continue }
            let own = declarations(in: path)
            var localNames: [String: AdaScriptSourceRange] = [:]
            var namespaces: [String: String] = [:]
            func bind(_ name: String, at range: AdaScriptSourceRange) {
                if own[name] != nil || localNames[name] != nil {
                    diagnostics.append(AdaScriptModuleDiagnostic(
                        message: "'\(name)' is already declared or imported in this module; rename it or import it with 'as'",
                        path: path,
                        range: range
                    ))
                } else {
                    localNames[name] = range
                }
            }
            for declaration in tree.imports {
                guard let resolved = try? AdaScriptModulePaths.resolveImport(declaration.path, from: path) else { continue }
                let exports: [String: AdaScriptDeclarationVisibility]?
                switch resolved {
                case let .source(target): exports = modules[target] == nil ? nil : declarations(in: target)
                case let .virtual(name): exports = AdaScriptVirtualModules.exports(of: name)
                }
                switch declaration.kind {
                case let .selected(bindings):
                    for binding in bindings {
                        bind(binding.localName, at: binding.range)
                        guard let exports else { continue }
                        switch exports[binding.name] {
                        case .public?: break
                        case .private?:
                            diagnostics.append(AdaScriptModuleDiagnostic(
                                message: "'\(binding.name)' is private to '\(declaration.path)' and cannot be imported",
                                path: path,
                                range: binding.range
                            ))
                        case nil:
                            diagnostics.append(AdaScriptModuleDiagnostic(
                                message: "'\(declaration.path)' does not export '\(binding.name)'",
                                path: path,
                                range: binding.range
                            ))
                        }
                    }
                case let .namespace(alias):
                    bind(alias, at: declaration.range)
                    if case let .source(target) = resolved, modules[target] != nil {
                        namespaces[alias] = target
                    }
                }
            }
            diagnostics += namespaceMemberDiagnostics(path: path, tree: tree, namespaces: namespaces)
            diagnostics += unimportedUseDiagnostics(path: path, tree: tree, importedNames: Set(localNames.keys), scope: scope)
        }
        diagnostics += duplicateDeclarationDiagnostics(scope: scope)
        return diagnostics
    }

    /// A module may only use another module's declarations by importing them. Without this, the
    /// flattened Gravity scope would let any reachable file call any other file's helpers.
    private func unimportedUseDiagnostics(
        path: String,
        tree: AdaScriptSyntaxTree,
        importedNames: Set<String>,
        scope: Set<String>?
    ) -> [AdaScriptModuleDiagnostic] {
        var owners: [String: String] = [:]
        for other in sortedPaths where other != path && (scope?.contains(other) ?? true) {
            for name in helperDeclarations(in: other) where owners[name] == nil { owners[name] = other }
        }
        guard !owners.isEmpty else { return [] }
        let known = tree.declaredNames.union(importedNames)
        var reported = Set<String>()
        var diagnostics: [AdaScriptModuleDiagnostic] = []
        for reference in tree.references where !known.contains(reference.name) {
            guard let owner = owners[reference.name], reported.insert(reference.name).inserted else { continue }
            diagnostics.append(AdaScriptModuleDiagnostic(
                message: "'\(reference.name)' is declared in '\(owner)'; import it with import { \(reference.name) } from \"...\"",
                path: path,
                range: reference.range
            ))
        }
        return diagnostics
    }

    private func namespaceMemberDiagnostics(path: String, tree: AdaScriptSyntaxTree, namespaces: [String: String]) -> [AdaScriptModuleDiagnostic] {
        guard !namespaces.isEmpty else { return [] }
        var diagnostics: [AdaScriptModuleDiagnostic] = []
        for use in tree.importUses {
            guard case let .namespaceMember(alias, member) = use.kind, let target = namespaces[alias] else { continue }
            let exports = declarations(in: target)
            switch exports[member] {
            case .public?: continue
            case .private?:
                diagnostics.append(AdaScriptModuleDiagnostic(message: "'\(member)' is private to '\(target)'", path: path, range: use.range))
            case nil:
                diagnostics.append(AdaScriptModuleDiagnostic(message: "'\(target)' does not export '\(member)'", path: path, range: use.range))
            }
        }
        return diagnostics
    }

    /// Gravity has one global scope, so a name declared by two modules cannot coexist. Naming both
    /// files up front is clearer than the compiler's redeclaration error.
    private func duplicateDeclarationDiagnostics(scope: Set<String>?) -> [AdaScriptModuleDiagnostic] {
        var owners: [String: [(path: String, range: AdaScriptSourceRange)]] = [:]
        for path in sortedPaths where scope?.contains(path) ?? true {
            guard let tree = modules[path]?.tree else { continue }
            for type in tree.types { owners[type.name, default: []].append((path, type.range)) }
            for function in tree.functions { owners[function.name, default: []].append((path, function.range)) }
            for binding in tree.bindings { owners[binding.name, default: []].append((path, binding.range)) }
        }
        var diagnostics: [AdaScriptModuleDiagnostic] = []
        for (name, declared) in owners.sorted(by: { $0.key < $1.key }) {
            let distinct = Set(declared.map(\.path))
            guard distinct.count > 1 else { continue }
            let files = distinct.sorted().joined(separator: ", ")
            // Every declaring module gets the finding, so whichever file is open shows it.
            for entry in declared {
                diagnostics.append(AdaScriptModuleDiagnostic(
                    message: "'\(name)' is declared in more than one module (\(files)); modules share one global scope, so rename one",
                    path: entry.path,
                    range: entry.range
                ))
            }
        }
        return diagnostics
    }
}
