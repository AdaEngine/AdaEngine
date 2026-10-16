#if os(Windows)
import Foundation

/// Runs CLI tools without creating desktop console windows. Their output remains
/// available in Studio. As with Foundation.Process, tools can start persistent
/// services (for example adb); cancelling a command terminates its direct process.
actor EditorProcessRunner: EditorProcessRunning {
    private var activeProcesses: [UUID: EditorWindowsProcess] = [:]

    func run(_ command: EditorProcessCommand) async -> EditorProcessResult {
        await run(command) { _ in }
    }

    func run(_ command: EditorProcessCommand, output: @Sendable @escaping (EditorProcessOutputEvent) async -> Void) async -> EditorProcessResult {
        let process: EditorWindowsProcess
        do {
            let executable = EditorHostTools.isAbsolutePath(command.executablePath)
                ? command.executablePath : EditorHostTools.executable(command.executablePath)
            process = try EditorWindowsProcess(
                executable: URL(fileURLWithPath: executable), arguments: command.arguments,
                directory: command.workingDirectory, environment: EditorHostTools.mergedEnvironment(command.environment),
                superviseTree: false
            )
            try? process.input.close()
        } catch {
            return EditorProcessResult(command: command, exitCode: 127, standardOutput: "", standardError: error.localizedDescription)
        }
        let id = UUID()
        activeProcesses[id] = process
        defer { activeProcesses[id] = nil }

        // This owned task must finish draining and reap the child even if the caller
        // is cancelled. AsyncStream iteration in a cancelled task ends prematurely.
        let completion = Task {
            async let stdout = Self.collect(process.output, stream: .standardOutput, output: output)
            async let stderr = Self.collect(process.error, stream: .standardError, output: output)
            var code: Int32 = 1
            for await status in process.exit { code = status }
            return await EditorProcessResult(command: command, exitCode: code, standardOutput: stdout, standardError: stderr)
        }
        return await withTaskCancellationHandler {
            await completion.value
        } onCancel: {
            process.terminate()
        }
    }

    private nonisolated static func collect(
        _ handle: FileHandle, stream: EditorProcessOutputStream,
        output: @Sendable @escaping (EditorProcessOutputEvent) async -> Void
    ) async -> String {
        let chunks = AsyncStream<Data> { continuation in
            handle.readabilityHandler = { readable in
                let data = readable.availableData
                if data.isEmpty {
                    readable.readabilityHandler = nil
                    continuation.finish()
                } else {
                    continuation.yield(data)
                }
            }
        }
        defer { handle.readabilityHandler = nil }
        var data = Data()
        var pendingText = Data()
        for await chunk in chunks {
            data.append(chunk)
            pendingText.append(chunk)
            // A pipe read may split a multi-byte UTF-8 scalar.
            if let text = String(data: pendingText, encoding: .utf8) {
                pendingText.removeAll(keepingCapacity: true)
                await output(EditorProcessOutputEvent(stream: stream, text: text))
            }
        }
        if !pendingText.isEmpty {
            await output(EditorProcessOutputEvent(stream: stream, text: String(decoding: pendingText, as: UTF8.self)))
        }
        return String(decoding: data, as: UTF8.self)
    }

    func cancelAll() {
        for process in activeProcesses.values { process.terminate() }
    }
}
#endif
