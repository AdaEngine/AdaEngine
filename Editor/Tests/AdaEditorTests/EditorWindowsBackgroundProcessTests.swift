#if os(Windows)
import Foundation
import Testing
@testable import AdaEditor

@Suite("Windows background tools", .enabled(if: FileManager.default.isExecutableFile(atPath: EditorHostTools.executable("python.exe"))))
struct EditorWindowsBackgroundProcessTests {
    @Test("A console tool has no console window and preserves argv, cwd, environment and diagnostics")
    func launchesWithoutConsole() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Tool test \(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let arguments = ["", "a b", "quote\"value", "tail\\", "& %PATH% |", "Игра 🌈"]
        let code = """
        import ctypes, json, os, sys
        print(json.dumps({'console': ctypes.windll.kernel32.GetConsoleWindow(), 'args': sys.argv[1:], 'cwd': os.getcwd(), 'value': os.environ['ADA_TOOL_TEST']}))
        sys.stderr.write('tool diagnostic')
        sys.exit(7)
        """
        let result = await EditorProcessRunner().run(.init(
            executablePath: "python.exe", arguments: ["-c", code] + arguments, workingDirectory: directory,
            environment: ["ADA_TOOL_TEST": "literal & value"]
        ))
        let payload = try #require(JSONSerialization.jsonObject(with: Data(result.standardOutput.utf8)) as? [String: Any])
        #expect(payload["console"] as? Int == 0)
        #expect(payload["args"] as? [String] == arguments)
        #expect((payload["cwd"] as? String)?.replacingOccurrences(of: "\\", with: "/").lowercased() == directory.path.lowercased())
        #expect(payload["value"] as? String == "literal & value")
        #expect(result.exitCode == 7)
        #expect(result.standardError == "tool diagnostic")
    }

    @Test("Tool output drains both pipes and retains split UTF-8 characters")
    func drainsOutput() async {
        let output = Output()
        let code = """
        import os, sys, time
        for byte in 'Привет 🌈'.encode('utf-8'):
            os.write(1, bytes([byte]))
            time.sleep(0.005)
        os.write(2, b'e' * 131072)
        """
        let result = await EditorProcessRunner().run(.init(
            executablePath: "python.exe", arguments: ["-c", code], workingDirectory: FileManager.default.temporaryDirectory
        )) { event in await output.append(event) }
        #expect(result.succeeded)
        #expect(result.standardOutput == "Привет 🌈")
        #expect(result.standardError.count == 131072)
        #expect(await output.standardOutput == result.standardOutput)
        #expect(await output.standardError == result.standardError)
    }

    @Test("Cancellation reaps a running tool and retains its output")
    func cancelsTool() async {
        let runner = EditorProcessRunner()
        let ready = AsyncStream<Void>.makeStream()
        let task = Task {
            let result = await runner.run(.init(
                executablePath: "python.exe", arguments: ["-u", "-c", "import time; print('ready'); time.sleep(30)"],
                workingDirectory: FileManager.default.temporaryDirectory
            )) { event in
                if event.text.contains("ready") { ready.continuation.yield(()) }
            }
            ready.continuation.finish()
            return result
        }
        for await _ in ready.stream { break }
        task.cancel()
        await runner.cancelAll()
        let result = await task.value
        #expect(!result.succeeded)
        #expect(result.standardOutput.contains("ready"))
    }

    @Test("Missing tools report a launch failure")
    func missingTool() async {
        let result = await EditorProcessRunner().run(.init(
            executablePath: "missing-tool-\(UUID()).exe", arguments: [], workingDirectory: FileManager.default.temporaryDirectory
        ))
        #expect(result.exitCode == 127)
        #expect(!result.standardError.isEmpty)
    }

    @Test("Supervised stdio services receive input without a console")
    func exchangesServiceMessages() async throws {
        let process = try EditorWindowsProcess(
            executable: URL(fileURLWithPath: EditorHostTools.executable("python.exe")),
            arguments: ["-c", "import ctypes, sys; print(ctypes.windll.kernel32.GetConsoleWindow()); print(sys.stdin.buffer.read().decode('utf-8'))"],
            directory: FileManager.default.temporaryDirectory,
            environment: EditorHostTools.mergedEnvironment(["PYTHONIOENCODING": "utf-8"])
        )
        try process.input.write(contentsOf: Data("Сообщение 🌈".utf8))
        try process.input.close()
        var exitCode: Int32 = -1
        for await status in process.exit { exitCode = status }
        let data = try #require(try process.output.readToEnd())
        let lines = String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline)
        #expect(exitCode == 0)
        #expect(lines == ["0", "Сообщение 🌈"])
    }

    private actor Output {
        var standardOutput = ""
        var standardError = ""
        func append(_ event: EditorProcessOutputEvent) {
            switch event.stream {
            case .standardOutput: standardOutput += event.text
            case .standardError: standardError += event.text
            }
        }
    }
}
#endif
