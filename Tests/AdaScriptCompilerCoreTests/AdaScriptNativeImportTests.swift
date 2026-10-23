import Foundation
import Testing

@testable import AdaScriptCompilerCore

@Suite("Native source module preparation")
struct AdaScriptNativeImportTests {
    @Test("Static runtime selection ignores comments and string contents")
    func staticSelection() {
        #expect(AdaScriptNativeSourceBuilder.requiresInterpretedRuntime(sources: [
            .init(path: "State.ada", source: "class State { static var count = 0; }")
        ]))
        #expect(!AdaScriptNativeSourceBuilder.requiresInterpretedRuntime(sources: [
            .init(path: "Label.ada", source: "// static var count = 0;\nfunc label() { return \"static\"; }")
        ]))
    }

    @Test("Selected and namespace imports compile and execute through the real native compiler",
          .enabled(if: ProcessInfo.processInfo.environment["ADAENGINE_GRAVITY_PACKAGE_PATH"] != nil))
    func nativeImports() throws {
        let compiler = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["ADAENGINE_GRAVITY_PACKAGE_PATH"]))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("NativeImports-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let sources = try AdaScriptNativeSourceBuilder.prepare(sources: [
            .init(path: "Main.ada", source: """
            import { answer as renamed } from "./ZLibrary.ada";
            import * as Library from "./ZLibrary.ada";
            func probe() { return renamed() + Library.answer(); }
            """),
            .init(path: "ZLibrary.ada", source: "func answer() { return 42; }")
        ], constructors: [:])
        let paths = try sources.enumerated().map { index, source in
            let path = root.appendingPathComponent("\(index).ada")
            try source.source.write(to: path, atomically: true, encoding: .utf8)
            return path.path
        }
        #if os(Windows)
        let host = compiler.appendingPathComponent("gravity.exe")
        let output = root.appendingPathComponent("probe.exe")
        #else
        let host = compiler.appendingPathComponent("gravity")
        let output = root.appendingPathComponent("probe")
        #endif
        try run(executable("python"), [compiler.appendingPathComponent("tools/aot_build.py").path] + paths + [
            "--module", "native_imports", "--output", root.appendingPathComponent("native_imports.c").path, "--gravity", host.path
        ])
        let driver = root.appendingPathComponent("probe.c")
        try """
        #include "native_imports.h"
        #include <string.h>
        int main(void) {
            const gravity_aot_module *module = native_imports_get_module();
            gravity_aot_context context = gravity_aot_context_init(100000);
            for (unsigned i = 0; i < module->count; ++i) {
                if (strcmp(module->exports[i].name, "probe")) continue;
                gravity_aot_value value = module->exports[i].call(&context, 0, 0);
                return context.error || value.kind != GRAVITY_AOT_INT || value.integer != 84;
            }
            return 2;
        }
        """.write(to: driver, atomically: true, encoding: .utf8)
        try run(executable("clang"), [driver.path, root.appendingPathComponent("native_imports.c").path, "-o", output.path])
        try run(output, [])
    }

    private func executable(_ name: String) throws -> URL {
        #if os(Windows)
        let separator: Character = ";"
        let filename = name + ".exe"
        #else
        let separator: Character = ":"
        let filename = name == "python" ? "python3" : name
        #endif
        let path = ProcessInfo.processInfo.environment.first { $0.key.caseInsensitiveCompare("PATH") == .orderedSame }?.value ?? ""
        return try #require(path.split(separator: separator).map {
            URL(fileURLWithPath: String($0)).appendingPathComponent(filename)
        }.first { FileManager.default.isExecutableFile(atPath: $0.path) })
    }

    private func run(_ executable: URL, _ arguments: [String]) throws {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0, Comment(rawValue: String(decoding: data, as: UTF8.self)))
    }
}
