import AdaScriptCompilerCore
import Foundation

public enum AdaScriptError: Error, Sendable, Equatable, CustomStringConvertible, LocalizedError {
    case compilation([String])
    case duplicateSourcePath(String)
    case importCycle([String])
    case invalidImport(source: String, message: String)
    case invalidManifest(String)
    case invalidSourcePath(String)
    case unknownComponent(system: String, queryIndex: Int, component: String)
    case unknownResource(system: String, resource: String)
    case unresolvedImport(source: String, importPath: String)

    public var description: String {
        switch self {
        case let .compilation(diagnostics):
            diagnostics.joined(separator: "\n")
        case let .duplicateSourcePath(path):
            "Duplicate Ada Script source path '\(path)'"
        case let .importCycle(paths):
            "Ada Script import cycle: \(paths.joined(separator: " -> "))"
        case let .invalidImport(source, message):
            "Invalid Ada Script import in '\(source)': \(message)"
        case let .invalidManifest(message):
            "Invalid Ada Script annotations: \(message)"
        case let .invalidSourcePath(path):
            "Invalid Ada Script source path '\(path)'"
        case let .unknownComponent(system, queryIndex, component):
            "Unknown component '\(component)' in query \(queryIndex) of system '\(system)'"
        case let .unknownResource(system, resource):
            "Unknown resource '\(resource)' in system '\(system)'"
        case let .unresolvedImport(source, importPath):
            "Unable to resolve Ada Script import '\(importPath)' from '\(source)'"
        }
    }

    public var errorDescription: String? { description }
}

/// One source file embedded in an Ada Script module.
public typealias AdaScriptSource = AdaScriptCompilerSource

struct ResolvedGravityScriptModule: Sendable {
    struct Source: Sendable {
        let fileID: UInt32
        let source: String
    }

    let entrySource: String
    let sourcesByPath: [String: Source]
    let pathsByFileID: [UInt32: String]
    let nonSendableTypeNames: Set<String>
    let asyncDeclarations: [AdaScriptAsyncDeclaration]
    /// Import-visibility problems, formatted `path:line:column: message`. Reported after Gravity compiles
    /// the module so a syntax error in an imported file is never masked by a missing export.
    let importDiagnostics: [String]
    /// Whether `@test` functions and the assertion prelude are part of this module.
    var includesTests = false
    /// Every `@test` function of the module, in path then source order.
    var tests: [AdaScriptTestCase] = []
    /// Top-level `var` names, which a test run snapshots and restores so tests stay independent.
    var globalVariableNames: [String] = []

    /// Every source in the module, for scans that must see imported files as well as the entry.
    var combinedSource: String {
        sourcesByPath.keys.sorted().compactMap { sourcesByPath[$0]?.source }.joined(separator: "\n")
    }

    func requireSynchronousCallback(className: String, method: String, annotation: String) throws {
        guard let declaration = asyncDeclarations.first(where: { $0.ownerType == className && $0.name == method }) else {
            return
        }
        throw AdaScriptError.invalidManifest(
            "\(annotation) callback '\(className).\(method)' at line \(declaration.line) cannot be async"
        )
    }
}

enum GravityScriptModuleResolver {
    /// - Parameter includeTests: Keep `@test` functions. Production modules leave this off, which removes every test
    ///   and rejects production code that references a test-only name (ADR-0024).
    static func resolve(_ allSources: [AdaScriptSource], includeTests: Bool = false) throws -> ResolvedGravityScriptModule {
        // The Tests/ root exists only in the test configuration (ADR-0024).
        let sources = try includeTests ? allSources : allSources.filter { source in
            !AdaScriptTestSupport.isTestSource(try canonicalSourcePath(source.path))
        }
        let graph: AdaScriptModuleGraph
        do {
            graph = try AdaScriptModuleGraph(sources: sources)
        } catch {
            throw AdaScriptError(error)
        }
        var sourceByPath: [String: AdaScriptSource] = [:]
        for source in sources {
            sourceByPath[try canonicalSourcePath(source.path)] = source
        }
        for path in graph.sortedPaths {
            if let problem = graph.modules[path]?.tree.importDiagnostics.first {
                throw AdaScriptError.invalidImport(source: path, message: problem.message)
            }
        }

        let sortedPaths = graph.sortedPaths
        let compilerSources = sortedPaths.compactMap { sourceByPath[$0] }
        let schemas = try AdaScriptSchemaParser.parse(sources: compilerSources)
        var analysisEnvironment = AdaScriptTypeEnvironment.standard
        analysisEnvironment.register(schemas: schemas)
        let analysis = AdaScriptAnalyzer.analyze(sources: compilerSources, environment: analysisEnvironment)
        do {
            try analysis.requireValidTypes(mode: .dynamic)
        } catch let error as AdaScriptTypeCheckingError {
            throw AdaScriptError.compilation(error.description.components(separatedBy: "\n"))
        }
        let discoveryRoots = sortedPaths.filter { path in
            guard let tree = graph.modules[path]?.tree else {
                return false
            }
            return tree.annotationUses.contains { rootAnnotations.contains($0.name) }
        }
        let roots = discoveryRoots.isEmpty ? sortedPaths : discoveryRoots

        let orderedPaths: [String]
        do {
            orderedPaths = try graph.order(roots: roots)
        } catch {
            throw AdaScriptError(error)
        }
        var annotationProblems: [String] = []
        for path in orderedPaths {
            for problem in AdaScriptAnnotationCatalog.problems(in: graph.modules[path]?.tree.annotationUses ?? []) {
                annotationProblems.append("\(path):\(problem.use.range.start.line + 1):\(problem.use.range.start.utf16Column + 1): \(problem.message)")
            }
        }
        for path in orderedPaths {
            if let tree = graph.modules[path]?.tree {
                annotationProblems += AdaScriptTestSupport.problems(in: tree)
                annotationProblems += AdaScriptTestSupport.testImportProblems(in: tree)
            }
        }
        if !annotationProblems.isEmpty {
            throw AdaScriptError.compilation(annotationProblems)
        }
        // Only modules the entry reaches share a Gravity scope; an unused file may reuse any name.
        let importDiagnostics = graph.semanticDiagnostics(scope: Set(orderedPaths))
            .map { "\($0.path):\($0.range.start.line + 1):\($0.range.start.utf16Column + 1): \($0.message)" }

        var nonSendableTypeNames = Set<String>()
        for path in orderedPaths {
            guard let source = sourceByPath[path] else {
                continue
            }
            do {
                nonSendableTypeNames.formUnion(try AdaScriptNonSendableTypes.declared(in: source.source, path: path))
            } catch let error as AdaScriptAsyncSyntaxError {
                throw AdaScriptError.invalidManifest(error.description)
            }
        }

        var asyncDeclarations: [AdaScriptAsyncDeclaration] = []
        for path in orderedPaths {
            guard let source = sourceByPath[path] else {
                continue
            }
            do {
                let declarations = try AdaScriptAsyncDeclarationScanner.declarations(
                    in: source.source,
                    path: path,
                    nonSendableTypes: nonSendableTypeNames
                )
                asyncDeclarations += declarations
            } catch let error as AdaScriptAsyncSyntaxError {
                throw AdaScriptError.invalidManifest(error.description)
            }
        }

        let testNames = Set(sortedPaths.flatMap { graph.modules[$0]?.tree.tests.map(\.name) ?? [] })
        let declaredNames = sortedPaths.reduce(into: Set<String>()) { $0.formUnion(graph.modules[$1]?.tree.declaredNames ?? []) }
        var testLeaks: [String] = []
        var loweredSources: [String: String] = [:]
        for path in sortedPaths {
            guard let source = sourceByPath[path], let tree = graph.modules[path]?.tree else {
                continue
            }
            // Imports are resolved above; Gravity sees one flat, include-ordered module.
            var importFreeSource = AdaScriptImportLowering.lower(source: source.source, tree: tree, stripTests: !includeTests)
            if includeTests {
                importFreeSource = AdaScriptTestLowerer.lower(source: importFreeSource, path: path, declared: declaredNames.subtracting(testNames))
            } else {
                testLeaks += AdaScriptTestSupport.leaks(
                    inStripped: importFreeSource,
                    path: path,
                    testNames: testNames,
                    declared: declaredNames.subtracting(testNames)
                )
            }
            importFreeSource = AdaScriptQueryLowerer.lower(source: importFreeSource)
            let loweredViewSource: String
            do {
                loweredViewSource = try AdaScriptViewBuilderLowerer.lower(
                    source: AdaScriptTypeAnnotationLowerer.lower(source: importFreeSource),
                    path: path
                )
            } catch let error as AdaScriptViewBuilderError {
                throw AdaScriptError.invalidManifest(error.description)
            }
            let loweredAssetsSource = AdaScriptAssetsLowerer.lower(source: loweredViewSource)
            let schemas = try AdaScriptSchemaParser.parse(sources: [source])
            let loweredComponentSource = AdaScriptComponentLowerer.lower(
                source: loweredAssetsSource,
                schemas: schemas
            )
            loweredSources[path] = AdaScriptMathLowerer.lower(
                source: AdaScriptNetworkLowerer.lower(source: loweredComponentSource)
            )
        }

        if !testLeaks.isEmpty {
            throw AdaScriptError.compilation(testLeaks)
        }

        var sourcesByPath: [String: ResolvedGravityScriptModule.Source] = [:]
        var pathsByFileID: [UInt32: String] = [:]
        for (offset, path) in sortedPaths.enumerated() {
            guard let source = loweredSources[path] else {
                continue
            }
            let fileID = UInt32(offset + 1)
            sourcesByPath[path] = .init(fileID: fileID, source: source)
            pathsByFileID[fileID] = path
        }

        let includes =
            orderedPaths
            .map { path in "#include \"\(escapeGravityString(path))\"" }
            .joined(separator: "\n")
        let entrySource = """
        extern var __adaAssets;
        \(includes)
        """

        var module = ResolvedGravityScriptModule(
            entrySource: entrySource,
            sourcesByPath: sourcesByPath,
            pathsByFileID: pathsByFileID,
            nonSendableTypeNames: nonSendableTypeNames,
            asyncDeclarations: asyncDeclarations,
            importDiagnostics: importDiagnostics
        )
        module.includesTests = includeTests
        if includeTests {
            module.globalVariableNames = sortedPaths.flatMap { path in
                (graph.modules[path]?.tree.bindings ?? []).filter { !$0.isConstant }.map(\.name)
            }
            module.tests = sortedPaths.flatMap { path in
                (graph.modules[path]?.tree.tests ?? []).map { test in
                    AdaScriptTestCase(
                        displayName: test.displayName,
                        line: test.range.start.line + 1,
                        name: test.name,
                        path: path
                    )
                }
            }
        }
        return module
    }

    private static let rootAnnotations: Set<String> = [
        "component",
        "network_command",
        "rpc",
        "replicated_component",
        "resource",
        "scriptable",
        "system",
        "test",
        "tool",
        "view",
    ]

    private static func canonicalSourcePath(_ path: String) throws -> String {
        do {
            return try AdaScriptModulePaths.canonicalSourcePath(path)
        } catch {
            throw AdaScriptError(error)
        }
    }

    private static func escapeGravityString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

extension AdaScriptError {
    init(_ error: AdaScriptModuleError) {
        switch error {
        case let .duplicateSourcePath(path): self = .duplicateSourcePath(path)
        case let .importCycle(paths): self = .importCycle(paths)
        case let .invalidImport(source, message): self = .invalidImport(source: source, message: message)
        case let .invalidSourcePath(path): self = .invalidSourcePath(path)
        case let .unresolvedImport(source, importPath): self = .unresolvedImport(source: source, importPath: importPath)
        }
    }
}
