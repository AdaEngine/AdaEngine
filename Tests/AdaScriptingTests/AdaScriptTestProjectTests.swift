import AdaScriptCompilerCore
@testable import AdaScripting
import Foundation
import Testing

@Suite("AdaScript test projects", .serialized)
struct AdaScriptTestProjectTests {
    private static let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures")

    static var projects: [URL] {
        let root = fixtures.appendingPathComponent("AdaScriptProjects")
        let entries = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return entries.filter { $0.hasDirectoryPath }.sorted { $0.path < $1.path }
    }

    @Test("Every fixture project passes its own Ada Script tests", arguments: projects)
    func fixtureProjectsPass(directory: URL) throws {
        let results = try AdaScriptTestProject.run(directory: directory)
        #expect(!results.isEmpty, "\(directory.lastPathComponent) has no tests")
        for result in results {
            #expect(result.outcome == .passed, "\(result.test.path): \(result.test.displayName): \(result.diagnostics)")
        }
    }

    @Test("Inline and Tests/ root tests are both found")
    func findsBothKinds() throws {
        let results = try AdaScriptTestProject.run(directory: Self.fixtures.appendingPathComponent("AdaScriptProjects/Falling"))
        let paths = Set(results.map(\.test.path))
        #expect(paths == ["Systems/Gravity.ada", "Tests/Integration.ada"])
    }

    @Test("The Tests/ root is left out of a production module")
    func testsRootIsNotShipped() throws {
        let directory = Self.fixtures.appendingPathComponent("AdaScriptProjects/Falling")
        let sources = try AdaScriptTestProject.sources(in: directory)
        #expect(sources.contains { $0.path == "Tests/Integration.ada" })
        let module = try GravityScriptModuleResolver.resolve(sources)
        #expect(!module.combinedSource.contains("fallsLikeTheFormula"))
        #expect(!module.combinedSource.contains("speedIsCapped"))
        #expect(module.combinedSource.contains("clampSpeed"))
    }

    @Test("Gameplay code cannot import from the Tests/ root")
    func gameplayCannotImportTests() {
        let sources = [
            AdaScriptSource(path: "Main.ada", source: "import { helper } from \"./Tests/Helpers\";\n@test func t() {}"),
            AdaScriptSource(path: "Tests/Helpers.ada", source: "func helper() { return 1; }"),
        ]
        do {
            _ = try GravityScriptModuleResolver.resolve(sources, includeTests: true)
            Issue.record("expected an error")
        } catch {
            #expect(String(describing: error).contains("Main.ada:1:"))
            #expect(String(describing: error).contains("gameplay code cannot import from the Tests/ root"))
        }
    }

    @Test("Reports list failures and render JUnit and JSON")
    func reports() throws {
        let results = try AdaScriptTestProject.run(directory: Self.fixtures.appendingPathComponent("AdaScriptProjectsFailing/Broken"))
        #expect(results.map(\.outcome) == [.passed, .failed])

        let summary = AdaScriptTestReport.summary(results)
        #expect(summary.contains("FAILED fails on purpose (Main.ada:5)"))
        #expect(summary.contains("1 passed, 1 failed, 2 total"))

        let junit = AdaScriptTestReport.junit(results, suiteName: "Broken")
        #expect(junit.contains("<testsuite name=\"Broken\" tests=\"2\" failures=\"1\">"))
        #expect(junit.contains("<failure message=\"Main.ada:5:"))

        let json = try AdaScriptTestReport.json(results)
        #expect(json.contains("\"passed\" : false"))
        #expect(json.contains("\"name\" : \"fails on purpose\""))
    }

    @Test("A test that loops forever times out, and the next test still runs")
    func timeout() throws {
        let sources = [
            AdaScriptSource(
                path: "Main.ada",
                source: """
                @test("spins")
                func spins() {
                    var i = 0;
                    while (true) { i += 1; }
                }

                @test("quick")
                func quick() {
                    expect(1 + 1 == 2);
                }
                """
            )
        ]
        var streamed: [String] = []
        let results = try AdaScriptTestProject.run(
            sources: sources,
            name: "Timeout",
            testTimeout: .milliseconds(200),
            onResult: { streamed.append($0.test.displayName) }
        )
        #expect(results.map(\.outcome) == [.failed, .passed])
        #expect(results[0].diagnostics.contains { $0.contains("timed out") })
        #expect(streamed == ["spins", "quick"])
    }

    @Test("A timeout limit does not fail tests that finish in time")
    func timeoutAllowsFastTests() throws {
        let results = try AdaScriptTestProject.run(directory: Self.fixtures.appendingPathComponent("AdaScriptProjects/Falling"), testTimeout: .seconds(30))
        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.outcome == .passed })
    }
}
