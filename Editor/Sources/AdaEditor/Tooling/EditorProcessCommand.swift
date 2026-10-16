import Foundation

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
    func run(_ command: EditorProcessCommand, output _: @Sendable @escaping (EditorProcessOutputEvent) async -> Void) async -> EditorProcessResult {
        await run(command)
    }
}

