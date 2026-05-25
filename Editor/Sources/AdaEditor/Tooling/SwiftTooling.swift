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
    func cancelAll() async
}

actor EditorProcessRunner: EditorProcessRunning {
    private var activeProcesses: [UUID: Process] = [:]

    func run(_ command: EditorProcessCommand) async -> EditorProcessResult {
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
            process.waitUntilExit()
        } catch {
            return EditorProcessResult(
                command: command,
                exitCode: 127,
                standardOutput: "",
                standardError: error.localizedDescription
            )
        }

        let standardOutput = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let standardError = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return EditorProcessResult(
            command: command,
            exitCode: process.terminationStatus,
            standardOutput: standardOutput,
            standardError: standardError
        )
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
    func execute(_ kind: SwiftPMCommandKind, projectURL: URL) async -> EditorProcessResult
    func semanticTokens(fileURL: URL, language: EditorSourceLanguage, text: String) async -> [EditorSemanticToken]
    func definition(fileURL: URL, language: EditorSourceLanguage, text: String, position: EditorSourceLocation) async -> [EditorSourceSymbolTarget]
    func references(fileURL: URL, language: EditorSourceLanguage, text: String, position: EditorSourceLocation) async -> [EditorSourceReference]
    func hover(fileURL: URL, language: EditorSourceLanguage, text: String, position: EditorSourceLocation) async -> EditorSymbolHover?
    func documentHighlights(fileURL: URL, language: EditorSourceLanguage, text: String, position: EditorSourceLocation) async -> [EditorDocumentHighlight]
    func cancel() async
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
        let resolvedToolchain = await SwiftToolchainLocator.locate()
        toolchain = resolvedToolchain

        let resolveResult = await processRunner.run(makeCommand(.resolve, projectURL: projectURL, toolchain: resolvedToolchain))
        let describeResult = await processRunner.run(makeCommand(.describe, projectURL: projectURL, toolchain: resolvedToolchain))
        let packageModel = describeResult.succeeded ? SwiftPackageModel.parse(from: describeResult.standardOutput) : nil

        if resolveResult.succeeded && describeResult.succeeded {
            await startSourceKitLSPIfAvailable(toolchain: resolvedToolchain, projectURL: projectURL)
        }

        let indexBuildResult: EditorProcessResult?
        if resolveResult.succeeded && describeResult.succeeded {
            indexBuildResult = await processRunner.run(makeCommand(.build(target: nil, buildTests: true), projectURL: projectURL, toolchain: resolvedToolchain))
        } else {
            indexBuildResult = nil
        }

        let diagnostics = [resolveResult, describeResult, indexBuildResult]
            .compactMap { $0 }
            .flatMap { EditorDiagnostic.diagnostics(from: $0, projectURL: projectURL) }

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
