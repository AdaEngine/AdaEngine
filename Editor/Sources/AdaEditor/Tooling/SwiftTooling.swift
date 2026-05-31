@preconcurrency import Foundation

struct SwiftToolchain: Equatable, Sendable {
    var swiftExecutablePath: String
    var sourceKitLSPExecutablePath: String?

    var hasSourceKitLSP: Bool {
        sourceKitLSPExecutablePath != nil
    }
}

enum SwiftToolchainLocator {
    static func locate(fileManager: FileManager = .default) async -> SwiftToolchain {
        let swiftPath = await findExecutable(["/usr/bin/swift", "/usr/local/bin/swift"], fallbackName: "swift", fileManager: fileManager) ?? "swift"
        let sourceKitPath = await findSourceKitLSP(fileManager: fileManager)

        return SwiftToolchain(
            swiftExecutablePath: swiftPath,
            sourceKitLSPExecutablePath: sourceKitPath
        )
    }

    private static func findSourceKitLSP(fileManager: FileManager) async -> String? {
        #if os(macOS)
        if let xcrunPath = await runCapture(executable: "/usr/bin/xcrun", arguments: ["--find", "sourcekit-lsp"]),
           fileManager.isExecutableFile(atPath: xcrunPath) {
            return xcrunPath
        }
        #endif

        return await findExecutable(
            [
                "/usr/bin/sourcekit-lsp",
                "/usr/local/bin/sourcekit-lsp",
                "/opt/homebrew/bin/sourcekit-lsp"
            ],
            fallbackName: "sourcekit-lsp",
            fileManager: fileManager
        )
    }

    private static func findExecutable(_ candidates: [String], fallbackName: String, fileManager: FileManager) async -> String? {
        for candidate in candidates where fileManager.isExecutableFile(atPath: candidate) {
            return candidate
        }

        return await runCapture(executable: "/usr/bin/env", arguments: ["which", fallbackName])
    }

    private static func runCapture(executable: String, arguments: [String]) async -> String? {
        await withCheckedContinuation { continuation in
            let process = Process()
            let output = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = output
            process.standardError = Pipe()
            process.terminationHandler = { process in
                let data = output.fileHandleForReading.readDataToEndOfFile()
                let value = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: process.terminationStatus == 0 && value?.isEmpty == false ? value : nil)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}

struct EditorProcessCommand: Equatable, Sendable {
    var executablePath: String
    var arguments: [String]
    var workingDirectory: URL
    var environment: [String: String]
    var displayName: String

    init(
        executablePath: String,
        arguments: [String],
        workingDirectory: URL,
        environment: [String: String] = [:],
        displayName: String? = nil
    ) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.environment = environment
        self.displayName = displayName ?? ([URL(fileURLWithPath: executablePath).lastPathComponent] + arguments).joined(separator: " ")
    }

    var shellDescription: String {
        displayName
    }
}



enum EditorProcessOutputStream: Equatable, Sendable {
    case standardOutput
    case standardError
}

struct EditorProcessOutputEvent: Equatable, Sendable {
    var stream: EditorProcessOutputStream
    var text: String
}

enum SwiftPMWorkspaceBootstrapPhase: String, Equatable, Sendable {
    case loadingProjectMetadata
    case locatingToolchain
    case resolvingDependencies
    case describingPackage
    case startingSourceKitLSP
    case scanningSources
    case indexingBuild
    case ready
    case failed
}

struct SwiftPMWorkspaceProgress: Equatable, Sendable {
    var phase: SwiftPMWorkspaceBootstrapPhase
    var title: String
    var detail: String?
    var completedFileCount: Int?
    var totalFileCount: Int?
    var currentFile: String?
    var currentTarget: String?
    var command: EditorProcessCommand?

    init(
        phase: SwiftPMWorkspaceBootstrapPhase,
        title: String,
        detail: String? = nil,
        completedFileCount: Int? = nil,
        totalFileCount: Int? = nil,
        currentFile: String? = nil,
        currentTarget: String? = nil,
        command: EditorProcessCommand? = nil
    ) {
        self.phase = phase
        self.title = title
        self.detail = detail
        self.completedFileCount = completedFileCount
        self.totalFileCount = totalFileCount
        self.currentFile = currentFile
        self.currentTarget = currentTarget
        self.command = command
    }

    var progressText: String {
        var value = title
        if let completedFileCount, let totalFileCount, totalFileCount > 0 {
            value += " \(completedFileCount)/\(totalFileCount)"
        }
        if let currentFile, !currentFile.isEmpty {
            value += " — \(currentFile)"
        }
        return value
    }
}

struct SwiftPMBuildProgressParser: Sendable {
    private(set) var completedFiles: Set<String> = []

    mutating func parse(line: String, knownFiles: [URL]) -> SwiftPMBuildProgress {
        let file = Self.swiftFileName(in: line)
        if let file {
            if let knownFile = knownFiles.first(where: { $0.lastPathComponent == file || $0.path.hasSuffix(file) }) {
                completedFiles.insert(knownFile.path)
            } else {
                completedFiles.insert(file)
            }
        }
        return SwiftPMBuildProgress(completed: completedFiles.count, currentFile: file, currentTarget: Self.targetName(in: line))
    }

    static func swiftFileName(in line: String) -> String? {
        let components = line.split { $0 == " " || $0 == "\t" || $0 == ":" || $0 == "(" || $0 == ")" }
        return components.map(String.init).first { $0.hasSuffix(".swift") }
    }

    static func targetName(in line: String) -> String? {
        let tokens = line.split { $0 == " " || $0 == "\t" }.map(String.init)
        guard let compilingIndex = tokens.firstIndex(of: "Compiling"), tokens.indices.contains(tokens.index(after: compilingIndex)) else {
            return nil
        }
        let candidate = tokens[tokens.index(after: compilingIndex)]
        return candidate.hasSuffix(".swift") ? nil : candidate
    }
}

struct SwiftPMBuildProgress: Equatable, Sendable {
    var completed: Int
    var currentFile: String?
    var currentTarget: String?
}

private actor SwiftPMBuildProgressTracker {
    private var parser = SwiftPMBuildProgressParser()

    func parse(line: String, knownFiles: [URL]) -> SwiftPMBuildProgress {
        parser.parse(line: line, knownFiles: knownFiles)
    }
}


struct EditorProcessResult: Equatable, Sendable {
    var command: EditorProcessCommand
    var exitCode: Int32
    var standardOutput: String
    var standardError: String

    var succeeded: Bool {
        exitCode == 0
    }

    var combinedOutput: String {
        [standardOutput, standardError]
            .filter { !$0.isEmpty }
            .joined(separator: standardOutput.isEmpty || standardError.isEmpty ? "" : "\n")
    }
}

protocol EditorProcessRunning: Sendable {
    func run(_ command: EditorProcessCommand) async -> EditorProcessResult
    func run(_ command: EditorProcessCommand, output: @Sendable @escaping (EditorProcessOutputEvent) async -> Void) async -> EditorProcessResult
    func cancelAll() async
}

extension EditorProcessRunning {
    func run(_ command: EditorProcessCommand, output: @Sendable @escaping (EditorProcessOutputEvent) async -> Void) async -> EditorProcessResult {
        await run(command)
    }
}

actor EditorProcessRunner: EditorProcessRunning {
    private var activeProcesses: [UUID: Process] = [:]

    func run(_ command: EditorProcessCommand) async -> EditorProcessResult {
        await run(command) { _ in }
    }

    func run(_ command: EditorProcessCommand, output outputHandler: @Sendable @escaping (EditorProcessOutputEvent) async -> Void) async -> EditorProcessResult {
        let processID = UUID()
        let process = Process()
        let output = Pipe()
        let error = Pipe()

        process.executableURL = URL(fileURLWithPath: command.executablePath)
        process.arguments = command.arguments
        process.currentDirectoryURL = command.workingDirectory
        process.standardOutput = output
        process.standardError = error
        process.environment = ProcessInfo.processInfo.environment.merging(command.environment) { _, new in new }

        activeProcesses[processID] = process
        defer { activeProcesses[processID] = nil }

        do {
            try process.run()
        } catch {
            return EditorProcessResult(
                command: command,
                exitCode: 127,
                standardOutput: "",
                standardError: error.localizedDescription
            )
        }

        async let standardOutput = Self.collectOutput(from: output, stream: .standardOutput, output: outputHandler)
        async let standardError = Self.collectOutput(from: error, stream: .standardError, output: outputHandler)
        process.waitUntilExit()

        return await EditorProcessResult(
            command: command,
            exitCode: process.terminationStatus,
            standardOutput: standardOutput,
            standardError: standardError
        )
    }

    nonisolated private static func collectOutput(
        from pipe: Pipe,
        stream: EditorProcessOutputStream,
        output: @Sendable @escaping (EditorProcessOutputEvent) async -> Void
    ) async -> String {
        var collected = Data()
        while true {
            let data = pipe.fileHandleForReading.availableData
            guard !data.isEmpty else {
                break
            }
            collected.append(data)
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                await output(EditorProcessOutputEvent(stream: stream, text: text))
            }
        }
        return String(data: collected, encoding: .utf8) ?? ""
    }

    func cancelAll() {
        for process in activeProcesses.values where process.isRunning {
            process.terminate()
        }
    }
}

enum SwiftPMCommandKind: Equatable, Sendable {
    case resolve
    case describe
    case build(target: String?, buildTests: Bool)
    case run(target: String?, arguments: [String])
    case test(filter: String?)
    case update
    case clean
    case reset
}

struct SwiftPackageModel: Equatable, Sendable {
    var name: String
    var products: [SwiftPackageProduct]
    var targets: [SwiftPackageTarget]
    var dependencies: [SwiftPackageDependency]

    var executableTargets: [String] {
        products.filter { $0.type == "executable" }.flatMap(\.targets)
    }

    var testTargets: [String] {
        targets.filter { $0.type == "test" }.map(\.name)
    }

    var pluginTargets: [String] {
        targets.filter { $0.type == "plugin" }.map(\.name)
    }
}

struct SwiftPackageProduct: Equatable, Sendable {
    var name: String
    var type: String
    var targets: [String]
}

struct SwiftPackageTarget: Equatable, Sendable {
    var name: String
    var type: String
    var path: String?
    var sources: [String]
    var targetDependencies: [String]
    var productDependencies: [String]
}

struct SwiftPackageDependency: Equatable, Sendable {
    var identity: String
    var type: String
    var url: String?
    var path: String?
    var requirement: String?
}

struct SwiftPMBootstrapResult: Equatable, Sendable {
    var toolchain: SwiftToolchain
    var resolveResult: EditorProcessResult
    var packageModel: SwiftPackageModel?
    var describeResult: EditorProcessResult
    var indexBuildResult: EditorProcessResult?
    var diagnostics: [EditorDiagnostic]

    var succeeded: Bool {
        resolveResult.succeeded && describeResult.succeeded
    }
}

protocol SwiftPMWorkspaceServicing: Sendable {
    func makeCommand(_ kind: SwiftPMCommandKind, projectURL: URL, toolchain: SwiftToolchain) -> EditorProcessCommand
    func bootstrap(projectURL: URL) async -> SwiftPMBootstrapResult
    func bootstrap(projectURL: URL, progress: @Sendable @escaping (SwiftPMWorkspaceProgress) async -> Void) async -> SwiftPMBootstrapResult
    func execute(_ kind: SwiftPMCommandKind, projectURL: URL) async -> EditorProcessResult
    func semanticTokens(fileURL: URL, language: EditorSourceLanguage, text: String) async -> [EditorSemanticToken]
    func definition(fileURL: URL, language: EditorSourceLanguage, text: String, position: EditorSourceLocation) async -> [EditorSourceSymbolTarget]
    func references(fileURL: URL, language: EditorSourceLanguage, text: String, position: EditorSourceLocation) async -> [EditorSourceReference]
    func hover(fileURL: URL, language: EditorSourceLanguage, text: String, position: EditorSourceLocation) async -> EditorSymbolHover?
    func documentHighlights(fileURL: URL, language: EditorSourceLanguage, text: String, position: EditorSourceLocation) async -> [EditorDocumentHighlight]
    func cancel() async
}

extension SwiftPMWorkspaceServicing {
    func bootstrap(projectURL: URL, progress: @Sendable @escaping (SwiftPMWorkspaceProgress) async -> Void) async -> SwiftPMBootstrapResult {
        await bootstrap(projectURL: projectURL)
    }
}

actor SwiftPMWorkspaceService: SwiftPMWorkspaceServicing {
    private let processRunner: any EditorProcessRunning
    private var toolchain: SwiftToolchain?
    private var sourceKitClient: SourceKitLSPClient?

    init(processRunner: any EditorProcessRunning = EditorProcessRunner()) {
        self.processRunner = processRunner
    }

    nonisolated func makeCommand(_ kind: SwiftPMCommandKind, projectURL: URL, toolchain: SwiftToolchain) -> EditorProcessCommand {
        let arguments: [String] = switch kind {
        case .resolve:
            ["package", "resolve"]
        case .describe:
            ["package", "describe", "--type", "json"]
        case .build(let target, let buildTests):
            buildArguments(target: target, buildTests: buildTests)
        case .run(let target, let arguments):
            runArguments(target: target, runArguments: arguments)
        case .test(let filter):
            testArguments(filter: filter)
        case .update:
            ["package", "update"]
        case .clean:
            ["package", "clean"]
        case .reset:
            ["package", "reset"]
        }

        return EditorProcessCommand(
            executablePath: toolchain.swiftExecutablePath,
            arguments: arguments,
            workingDirectory: projectURL
        )
    }

    func bootstrap(projectURL: URL) async -> SwiftPMBootstrapResult {
        await bootstrap(projectURL: projectURL) { _ in }
    }

    func bootstrap(projectURL: URL, progress: @Sendable @escaping (SwiftPMWorkspaceProgress) async -> Void) async -> SwiftPMBootstrapResult {
        await progress(SwiftPMWorkspaceProgress(phase: .loadingProjectMetadata, title: "Loading project metadata", detail: projectURL.path))
        await progress(SwiftPMWorkspaceProgress(phase: .locatingToolchain, title: "Locating Swift toolchain", detail: "Searching swift and sourcekit-lsp"))
        let resolvedToolchain = await SwiftToolchainLocator.locate()
        toolchain = resolvedToolchain
        await progress(SwiftPMWorkspaceProgress(
            phase: .locatingToolchain,
            title: "Swift toolchain found",
            detail: "swift: \(resolvedToolchain.swiftExecutablePath), sourcekit-lsp: \(resolvedToolchain.sourceKitLSPExecutablePath ?? "unavailable")"
        ))

        let resolveCommand = makeCommand(.resolve, projectURL: projectURL, toolchain: resolvedToolchain)
        await progress(SwiftPMWorkspaceProgress(phase: .resolvingDependencies, title: "Resolving SwiftPM dependencies", command: resolveCommand))
        let resolveResult = await processRunner.run(resolveCommand) { event in
            await progress(SwiftPMWorkspaceProgress(phase: .resolvingDependencies, title: "Resolving SwiftPM dependencies", detail: event.text.trimmingCharacters(in: .whitespacesAndNewlines), command: resolveCommand))
        }

        let describeCommand = makeCommand(.describe, projectURL: projectURL, toolchain: resolvedToolchain)
        await progress(SwiftPMWorkspaceProgress(phase: .describingPackage, title: "Reading SwiftPM package graph", command: describeCommand))
        let describeResult = resolveResult.succeeded
            ? await processRunner.run(describeCommand)
            : EditorProcessResult(command: describeCommand, exitCode: 1, standardOutput: "", standardError: "Skipped because dependency resolution failed.")
        let packageModel = describeResult.succeeded ? SwiftPackageModel.parse(from: describeResult.standardOutput) : nil

        if resolveResult.succeeded && describeResult.succeeded {
            let lspTitle = resolvedToolchain.hasSourceKitLSP ? "Starting SourceKit-LSP" : "SourceKit-LSP unavailable"
            await progress(SwiftPMWorkspaceProgress(phase: .startingSourceKitLSP, title: lspTitle, detail: resolvedToolchain.sourceKitLSPExecutablePath))
            await startSourceKitLSPIfAvailable(toolchain: resolvedToolchain, projectURL: projectURL)
        }

        let indexBuildResult: EditorProcessResult?
        if resolveResult.succeeded && describeResult.succeeded {
            let sourceFiles = Self.swiftSourceFiles(projectURL: projectURL, packageModel: packageModel, fileManager: .default)
            await progress(SwiftPMWorkspaceProgress(phase: .scanningSources, title: "Scanning Swift source files", completedFileCount: 0, totalFileCount: sourceFiles.count))
            await progress(SwiftPMWorkspaceProgress(phase: .scanningSources, title: "Scanned Swift source files", completedFileCount: sourceFiles.count, totalFileCount: sourceFiles.count))
            let buildCommand = makeCommand(.build(target: nil, buildTests: true), projectURL: projectURL, toolchain: resolvedToolchain)
            await progress(SwiftPMWorkspaceProgress(phase: .indexingBuild, title: "Indexing Swift package", completedFileCount: 0, totalFileCount: sourceFiles.count, command: buildCommand))
            let progressTracker = SwiftPMBuildProgressTracker()
            indexBuildResult = await processRunner.run(buildCommand) { event in
                let lines = event.text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                for line in lines {
                    let parsed = await progressTracker.parse(line: line, knownFiles: sourceFiles)
                    await progress(SwiftPMWorkspaceProgress(
                        phase: .indexingBuild,
                        title: "Indexing Swift package",
                        detail: line,
                        completedFileCount: parsed.completed,
                        totalFileCount: sourceFiles.count,
                        currentFile: parsed.currentFile,
                        currentTarget: parsed.currentTarget,
                        command: buildCommand
                    ))
                }
            }
        } else {
            indexBuildResult = nil
        }

        let diagnostics = [resolveResult, describeResult, indexBuildResult]
            .compactMap { $0 }
            .flatMap { EditorDiagnostic.diagnostics(from: $0, projectURL: projectURL) }

        await progress(SwiftPMWorkspaceProgress(
            phase: (resolveResult.succeeded && describeResult.succeeded && indexBuildResult?.succeeded != false) ? .ready : .failed,
            title: (resolveResult.succeeded && describeResult.succeeded && indexBuildResult?.succeeded != false) ? "Workspace ready" : "Workspace bootstrap failed"
        ))

        return SwiftPMBootstrapResult(
            toolchain: resolvedToolchain,
            resolveResult: resolveResult,
            packageModel: packageModel,
            describeResult: describeResult,
            indexBuildResult: indexBuildResult,
            diagnostics: diagnostics
        )
    }

    func execute(_ kind: SwiftPMCommandKind, projectURL: URL) async -> EditorProcessResult {
        let resolvedToolchain: SwiftToolchain
        if let toolchain {
            resolvedToolchain = toolchain
        } else {
            resolvedToolchain = await SwiftToolchainLocator.locate()
            toolchain = resolvedToolchain
        }

        return await processRunner.run(makeCommand(kind, projectURL: projectURL, toolchain: resolvedToolchain))
    }

    func cancel() async {
        await processRunner.cancelAll()
        await sourceKitClient?.stop()
        sourceKitClient = nil
    }

    func semanticTokens(fileURL: URL, language: EditorSourceLanguage, text: String) async -> [EditorSemanticToken] {
        guard let sourceKitClient else {
            return []
        }

        do {
            try await sourceKitClient.openDocument(fileURL: fileURL, language: language, text: text)
            return try await sourceKitClient.refreshSemanticTokens(fileURL: fileURL)
        } catch {
            return []
        }
    }

    func definition(fileURL: URL, language: EditorSourceLanguage, text: String, position: EditorSourceLocation) async -> [EditorSourceSymbolTarget] {
        guard let sourceKitClient else {
            return []
        }

        do {
            try await sourceKitClient.openDocument(fileURL: fileURL, language: language, text: text)
            return try await sourceKitClient.definition(fileURL: fileURL, position: position)
        } catch {
            return []
        }
    }

    func references(fileURL: URL, language: EditorSourceLanguage, text: String, position: EditorSourceLocation) async -> [EditorSourceReference] {
        guard let sourceKitClient else {
            return []
        }

        do {
            try await sourceKitClient.openDocument(fileURL: fileURL, language: language, text: text)
            return try await sourceKitClient.references(fileURL: fileURL, position: position)
        } catch {
            return []
        }
    }

    func hover(fileURL: URL, language: EditorSourceLanguage, text: String, position: EditorSourceLocation) async -> EditorSymbolHover? {
        guard let sourceKitClient else {
            return nil
        }

        do {
            try await sourceKitClient.openDocument(fileURL: fileURL, language: language, text: text)
            return try await sourceKitClient.hover(fileURL: fileURL, position: position)
        } catch {
            return nil
        }
    }

    func documentHighlights(fileURL: URL, language: EditorSourceLanguage, text: String, position: EditorSourceLocation) async -> [EditorDocumentHighlight] {
        guard let sourceKitClient else {
            return []
        }

        do {
            try await sourceKitClient.openDocument(fileURL: fileURL, language: language, text: text)
            return try await sourceKitClient.documentHighlights(fileURL: fileURL, position: position)
        } catch {
            return []
        }
    }

    nonisolated private func buildArguments(target: String?, buildTests: Bool) -> [String] {
        var arguments = ["build"]
        if buildTests {
            arguments.append("--build-tests")
        }
        if let target, !target.isEmpty {
            arguments += ["--target", target]
        }
        return arguments
    }

    nonisolated private func runArguments(target: String?, runArguments: [String]) -> [String] {
        var arguments = ["run"]
        if let target, !target.isEmpty {
            arguments.append(target)
        }
        if !runArguments.isEmpty {
            arguments.append("--")
            arguments += runArguments
        }
        return arguments
    }

    nonisolated private func testArguments(filter: String?) -> [String] {
        var arguments = ["test", "--parallel"]
        if let filter, !filter.isEmpty {
            arguments += ["--filter", filter]
        }
        return arguments
    }

    static func swiftSourceFiles(projectURL: URL, packageModel: SwiftPackageModel?, fileManager: FileManager = .default) -> [URL] {
        var files: Set<URL> = []
        if let packageModel {
            for target in packageModel.targets {
                let targetRoot = projectURL.appendingPathComponent(target.path ?? "Sources/\(target.name)", isDirectory: true)
                if target.sources.isEmpty {
                    for file in swiftFiles(under: targetRoot, fileManager: fileManager) {
                        files.insert(file.standardizedFileURL)
                    }
                } else {
                    for source in target.sources where source.hasSuffix(".swift") {
                        files.insert(targetRoot.appendingPathComponent(source, isDirectory: false).standardizedFileURL)
                    }
                }
            }
        }

        if files.isEmpty {
            for directory in ["Sources", "Tests"] {
                files.formUnion(swiftFiles(under: projectURL.appendingPathComponent(directory, isDirectory: true), fileManager: fileManager).map { $0.standardizedFileURL })
            }
        }
        return files.sorted { $0.path < $1.path }
    }

    private static func swiftFiles(under root: URL, fileManager: FileManager) -> [URL] {
        guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        return enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "swift" else { return nil }
            return url
        }
    }

    private func startSourceKitLSPIfAvailable(toolchain: SwiftToolchain, projectURL: URL) async {
        guard toolchain.sourceKitLSPExecutablePath != nil else {
            return
        }

        let client = SourceKitLSPClient(connection: SourceKitLSPStdioConnection())
        do {
            try await client.start(toolchain: toolchain, projectURL: projectURL)
            sourceKitClient = client
        } catch {
            await client.stop()
        }
    }
}

extension SwiftPackageModel {
    static func parse(from json: String) -> SwiftPackageModel? {
        guard let data = json.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(SwiftPackageDescription.self, from: data).model
    }
}

private struct SwiftPackageDescription: Decodable {
    var name: String
    var products: [Product]
    var targets: [Target]
    var dependencies: [Dependency]

    var model: SwiftPackageModel {
        SwiftPackageModel(
            name: name,
            products: products.map(\.model),
            targets: targets.map(\.model),
            dependencies: dependencies.map(\.model)
        )
    }

    struct Product: Decodable {
        var name: String
        var targets: [String]
        var type: JSONValue

        var model: SwiftPackageProduct {
            SwiftPackageProduct(name: name, type: type.objectKeys.first ?? "unknown", targets: targets)
        }
    }

    struct Target: Decodable {
        var name: String
        var type: String
        var path: String?
        var sources: [String]?
        var targetDependencies: [String]?
        var productDependencies: [String]?

        private enum CodingKeys: String, CodingKey {
            case name, type, path, sources
            case targetDependencies = "target_dependencies"
            case productDependencies = "product_dependencies"
        }

        var model: SwiftPackageTarget {
            SwiftPackageTarget(
                name: name,
                type: type,
                path: path,
                sources: sources ?? [],
                targetDependencies: targetDependencies ?? [],
                productDependencies: productDependencies ?? []
            )
        }
    }

    struct Dependency: Decodable {
        var identity: String
        var type: String?
        var url: String?
        var path: String?
        var requirement: JSONValue?

        var model: SwiftPackageDependency {
            SwiftPackageDependency(
                identity: identity,
                type: type ?? (path == nil ? "sourceControl" : "fileSystem"),
                url: url,
                path: path,
                requirement: requirement?.compactDescription
            )
        }
    }
}

private enum JSONValue: Decodable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    var objectKeys: [String] {
        guard case .object(let object) = self else {
            return []
        }
        return object.keys.sorted()
    }

    var compactDescription: String {
        switch self {
        case .string(let value):
            value
        case .number(let value):
            String(value)
        case .bool(let value):
            String(value)
        case .array(let values):
            values.map(\.compactDescription).joined(separator: ",")
        case .object(let object):
            object.keys.sorted().map { "\($0):\(object[$0]?.compactDescription ?? "")" }.joined(separator: ",")
        case .null:
            "null"
        }
    }
}
