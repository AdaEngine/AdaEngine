#if os(Linux)
import AdaEngine
import AdaScriptCompilerCore
import Foundation
import Testing

@Suite("Linux AdaScript UTF-8")
struct EditorLinuxUTF8Tests {
    @Test @MainActor func compilesWindowsLineEndingsAndUnicode() throws {
        let source = (String(repeating: "// A Windows-authored project\n", count: 80) + """
        @system(id: "linux.utf8")
        class UnicodeSystem {
            func update(context) {
                var message = "Привет, мир 🌍";
                System.print(message);
            }
        }
        """).replacingOccurrences(of: "\n", with: "\r\n")
        let systems = try AdaScriptSchemaParser.parseSystemCapabilities(sources: [
            AdaScriptCompilerSource(path: "Unicode.ada", source: source)
        ])
        #expect(systems.count == 1)
        let plugin = try AdaScriptPlugin(
            sources: [AdaScriptSource(path: "Unicode.ada", source: source)],
            name: "LinuxUTF8"
        )
        #expect(plugin.diagnostics.isEmpty)
    }
}
#endif
