#if os(Windows)
import Foundation

/// Resolves native executables and npm shims without interpreting agent arguments
/// as cmd.exe source. Spaces, Unicode and shell metacharacters remain literal argv.
enum EditorWindowsAgentCommand {
    static func environment(_ overrides: [String: String], inheriting base: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        EditorHostTools.mergedEnvironment(overrides, inheriting: base)
    }

    static func resolve(_ command: String, arguments: [String], environment: [String: String]) throws -> (executable: URL, arguments: [String]) {
        let paths = EditorAgentDiscovery.searchPaths(environment: environment, home: URL(fileURLWithPath: NSHomeDirectory()))
        let path = EditorHostTools.isAbsolutePath(command) ? command : EditorAgentDiscovery.executable(command, paths: paths)
        guard let path, FileManager.default.fileExists(atPath: path) else {
            throw EditorAgentCatalogError(message: "Agent executable was not found: \(command)")
        }
        let url = URL(fileURLWithPath: path)
        let ext = url.pathExtension.lowercased()
        if ["js", "cjs", "mjs"].contains(ext) {
            return try node(script: url, arguments: arguments, paths: [url.deletingLastPathComponent().path] + paths)
        }
        if ext == "cmd" || ext == "bat" {
            let directory = url.deletingLastPathComponent()
            let npm = directory.appendingPathComponent("node_modules/npm/bin/npm-cli.js")
            if url.deletingPathExtension().lastPathComponent.lowercased() == "npm", FileManager.default.fileExists(atPath: npm.path) {
                return try node(script: npm, arguments: arguments, paths: [directory.path] + paths)
            }
            let source = try String(contentsOf: url, encoding: .utf8)
            let expression = try NSRegularExpression(pattern: #"(?i)%(?:dp0%|~dp0)[\\/]?([^"\r\n]+\.(?:cjs|mjs|js))"#)
            for match in expression.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
                guard let range = Range(match.range(at: 1), in: source) else { continue }
                let script = directory.appendingPathComponent(String(source[range]).replacingOccurrences(of: "\\", with: "/")).standardizedFileURL
                if FileManager.default.fileExists(atPath: script.path) {
                    return try node(script: script, arguments: arguments, paths: [directory.path] + paths)
                }
            }
            throw EditorAgentCatalogError(message: "Select the agent's .exe or its Node.js entry point. This batch file is not an npm launcher: \(path)")
        }
        return (url, arguments)
    }

    private static func node(script: URL, arguments: [String], paths: [String]) throws -> (executable: URL, arguments: [String]) {
        guard let node = EditorAgentDiscovery.executable("node", paths: paths) else {
            throw EditorAgentCatalogError(message: "Install Node.js, then Refresh to launch this agent.")
        }
        return (URL(fileURLWithPath: node), [script.path] + arguments)
    }
}
#endif
