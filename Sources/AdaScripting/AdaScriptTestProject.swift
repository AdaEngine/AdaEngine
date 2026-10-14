import AdaScriptCompilerCore
import Foundation

/// Runs the `@test` functions of an Ada Script project on disk (ADR-0024).
///
/// A project's own Swift test can call `run(directory:)` so `swift test` and CI cover its Ada Script tests with no
/// extra step.
public enum AdaScriptTestProject {
    /// Every `.ada` file under `directory`, with paths relative to it, sorted. Hidden items are skipped.
    public static func sources(in directory: URL) throws -> [AdaScriptSource] {
        let root = directory.standardizedFileURL
        guard
            let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }
        var sources: [AdaScriptSource] = []
        for case let url as URL in enumerator where url.pathExtension == "ada" {
            let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
            let path = String(url.standardizedFileURL.path.dropFirst(prefix.count))
            sources.append(AdaScriptSource(path: path, source: try String(contentsOf: url, encoding: .utf8)))
        }
        return sources.sorted { $0.path < $1.path }
    }

    /// Loads the project with its `Tests/` root and runs every test, or those matching `filter`.
    public static func run(directory: URL, matching filter: String? = nil) throws -> [AdaScriptTestResult] {
        let plugin = try AdaScriptPlugin(
            sources: try sources(in: directory),
            name: directory.lastPathComponent,
            includeTests: true
        )
        return plugin.runTests(matching: filter)
    }
}

/// Text, JUnit and JSON renderings of test results, for terminals and CI.
public enum AdaScriptTestReport {
    /// One line per failed test plus a total.
    public static func summary(_ results: [AdaScriptTestResult]) -> String {
        let failed = results.filter { $0.outcome == .failed }
        var lines = failed.flatMap { result in
            ["FAILED \(result.test.displayName) (\(result.test.path):\(result.test.line))"] + result.diagnostics.map { "  \($0)" }
        }
        lines.append("\(results.count - failed.count) passed, \(failed.count) failed, \(results.count) total")
        return lines.joined(separator: "\n")
    }

    /// A JUnit `<testsuite>` document.
    public static func junit(_ results: [AdaScriptTestResult], suiteName: String) -> String {
        let failures = results.filter { $0.outcome == .failed }.count
        var lines = [
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
            "<testsuite name=\"\(escape(suiteName))\" tests=\"\(results.count)\" failures=\"\(failures)\">",
        ]
        for result in results {
            let attributes = "classname=\"\(escape(result.test.path))\" name=\"\(escape(result.test.displayName))\" time=\"\(String(format: "%.6f", seconds(result.duration)))\""
            if result.outcome == .passed {
                lines.append("  <testcase \(attributes)/>")
            } else {
                let message = escape(result.diagnostics.joined(separator: "\n"))
                lines.append("  <testcase \(attributes)><failure message=\"\(message)\"/></testcase>")
            }
        }
        lines.append("</testsuite>")
        return lines.joined(separator: "\n")
    }

    /// A JSON array of `{name, path, line, passed, durationSeconds, diagnostics}`.
    public static func json(_ results: [AdaScriptTestResult]) throws -> String {
        struct Entry: Encodable {
            let diagnostics: [String]
            let durationSeconds: Double
            let line: Int
            let name: String
            let passed: Bool
            let path: String
        }
        let entries = results.map { result in
            Entry(
                diagnostics: result.diagnostics,
                durationSeconds: seconds(result.duration),
                line: result.test.line,
                name: result.test.displayName,
                passed: result.outcome == .passed,
                path: result.test.path
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(decoding: try encoder.encode(entries), as: UTF8.self)
    }

    private static func seconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "\n", with: "&#10;")
    }
}
