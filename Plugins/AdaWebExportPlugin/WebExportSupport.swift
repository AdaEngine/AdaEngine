import Foundation

enum WebExportSupport {
    /// Ordinary scene exports must not build a second copy of the renderer.
    /// Prepared component payloads are base64 JSON; inline graphs need the baker
    /// even when there are no .shadergraph files in the package.
    static func needsShaderGraphBaker(_ file: URL) throws -> Bool {
        if file.pathExtension == "shadergraph" { return true }
        guard ["ascn", "gltf", "glb"].contains(file.pathExtension) else { return false }
        var data = try Data(contentsOf: file)
        if file.pathExtension == "glb" {
            guard data.count >= 20 else { return false }
            let length = data[12..<16].enumerated().reduce(0) { $0 | Int($1.element) << ($1.offset * 8) }
            guard length <= data.count - 20 else { return false }
            data = data.subdata(in: 20..<(20 + length))
        }
        func containsGraph(_ object: Any) -> Bool {
            if let dictionary = object as? [String: Any] {
                if dictionary["target"] != nil, dictionary["nodes"] != nil { return true }
                if let path = dictionary["path"] as? String, path.hasSuffix(".shadergraph") { return true }
                return dictionary.values.contains(where: containsGraph)
            }
            if let list = object as? [Any] { return list.contains(where: containsGraph) }
            if let text = object as? String, let nested = Data(base64Encoded: text),
               let object = try? JSONSerialization.jsonObject(with: nested) { return containsGraph(object) }
            return false
        }
        return containsGraph(try JSONSerialization.jsonObject(with: data))
    }

    static func captureStandardOutput(executable: String, arguments: [String], workingDirectory: URL?) throws -> String {
        let fileManager = FileManager.default
        let process = Process()
        // Both streams can exceed pipe capacity (Tint diagnostics and compiler
        // output). Files let the child finish without a blocked reader thread.
        let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }
        let outputURL = directory.appendingPathComponent("stdout")
        let errorURL = directory.appendingPathComponent("stderr")
        fileManager.createFile(atPath: outputURL.path, contents: nil)
        fileManager.createFile(atPath: errorURL.path, contents: nil)
        let standardOutput = try FileHandle(forWritingTo: outputURL)
        let standardError = try FileHandle(forWritingTo: errorURL)
        defer { try? standardOutput.close(); try? standardError.close() }
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory
        process.standardOutput = standardOutput
        process.standardError = standardError
        process.environment = ProcessInfo.processInfo.environment.merging([
            "ADAENGINE_WEB_EXPORT": "1",
            "BUILD_WASM": "1"
        ]) { _, new in new }
        try process.run()
        process.waitUntilExit()

        let data = try Data(contentsOf: outputURL)
        let output = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            let errorData = try Data(contentsOf: errorURL)
            let errorOutput = String(decoding: errorData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let command = ([executable] + arguments).joined(separator: " ")
            throw CommandError(
                errorOutput.isEmpty ? command : "\(command)\n\(errorOutput)",
                process.terminationStatus
            )
        }
        return output
    }

    struct CommandError: Error, CustomStringConvertible {
        let description: String
        init(_ message: String, _ status: Int32) {
            description = "Command failed (\(status)): \(message)"
        }
    }
}
