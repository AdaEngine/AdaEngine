import AdaScripting
import Foundation

/// Runs the `@test` functions of an Ada Script project (ADR-0024).
///
///     swift run AdaScriptTest <project-directory> [--filter text] [--format text|junit|json]
///
/// Exits 0 when every test passes, 1 when any fails or none are found, and 2 on a usage or load error.
@main
struct AdaScriptTest {
    static func main() {
        var arguments = Array(CommandLine.arguments.dropFirst())
        let filter = take("--filter", from: &arguments)
        let format = take("--format", from: &arguments) ?? "text"
        guard let path = arguments.first, arguments.count == 1, ["text", "junit", "json"].contains(format) else {
            fail("usage: AdaScriptTest <project-directory> [--filter text] [--format text|junit|json]")
        }
        let directory = URL(fileURLWithPath: path)
        do {
            let results = try AdaScriptTestProject.run(directory: directory, matching: filter)
            switch format {
            case "junit": print(AdaScriptTestReport.junit(results, suiteName: directory.lastPathComponent))
            case "json": print(try AdaScriptTestReport.json(results))
            default: print(AdaScriptTestReport.summary(results))
            }
            exit(!results.isEmpty && results.allSatisfy({ $0.outcome == .passed }) ? 0 : 1)
        } catch {
            fail("error: \(error)")
        }
    }

    private static func take(_ flag: String, from arguments: inout [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else {
            return nil
        }
        let value = arguments[index + 1]
        arguments.removeSubrange(index...(index + 1))
        return value
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(2)
    }
}
