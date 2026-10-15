import AdaScriptCompilerCore
@testable import AdaScripting
import Testing

@Suite("AdaScript test runner", .serialized)
struct AdaScriptTestRunnerTests {
    private func plugin(_ source: String) throws -> AdaScriptPlugin {
        try AdaScriptPlugin(
            sources: [AdaScriptSource(path: "Main.ada", source: source)],
            name: "RunnerTests",
            includeTests: true
        )
    }

    private func outcomes(_ results: [AdaScriptTestResult]) -> [String: AdaScriptTestResult.Outcome] {
        Dictionary(uniqueKeysWithValues: results.map { ($0.test.name, $0.outcome) })
    }

    @Test("Passing and failing expectations are reported with their call-site location")
    func passAndFail() throws {
        let results = try plugin("""
            private func double(v) { return v * 2; }

            @test("doubles")
            func doubles() {
                expectEqual(double(2), 4);
                expect(double(1) == 2);
            }

            @test
            func broken() {
                expect(double(1) == 3);
                expectEqual(double(2), 5);
            }
            """).runTests()
        #expect(outcomes(results) == ["doubles": .passed, "broken": .failed])
        let broken = try #require(results.first { $0.test.name == "broken" })
        #expect(broken.diagnostics.count == 2)
        #expect(broken.diagnostics[0] == "Main.ada:11:5: expectation failed")
        #expect(broken.diagnostics[1] == "Main.ada:12:5: expected 5 but got 4")
        #expect(results.first { $0.test.name == "doubles" }?.test.displayName == "doubles")
    }

    @Test("expectNear, expectNil and fail")
    func otherAssertions() throws {
        let results = try plugin("""
            @test func near() { expectNear(0.1 + 0.2, 0.3, 0.001); }
            @test func farAway() { expectNear(1.0, 2.0, 0.5); }
            @test func nothing() { expectNil(null); }
            @test func something() { expectNil(3); }
            @test func explicit() { fail("nope"); }
            """).runTests()
        #expect(outcomes(results) == [
            "near": .passed, "farAway": .failed, "nothing": .passed, "something": .failed, "explicit": .failed,
        ])
        #expect(results.first { $0.test.name == "explicit" }?.diagnostics == ["Main.ada:5:25: nope"])
    }

    @Test("A failed require stops that test only")
    func requireStopsTheTest() throws {
        let results = try plugin("""
            @test func stops() {
                require(false);
                expect(false);
            }
            @test func after() { expect(true); }
            """).runTests()
        #expect(outcomes(results) == ["stops": .failed, "after": .passed])
        let stops = try #require(results.first { $0.test.name == "stops" })
        #expect(stops.diagnostics == ["Main.ada:2:5: requirement failed"])
    }

    @Test("A runtime error fails its test and leaves the others runnable")
    func runtimeErrorIsIsolated() throws {
        let results = try plugin("""
            @test func explodes() {
                var list = [1];
                list.nothing();
            }
            @test func fine() { expect(true); }
            @test func alsoFine() { expectEqual(1 + 1, 2); }
            """).runTests()
        let byName = outcomes(results)
        #expect(byName["explodes"] == .failed)
        #expect(byName["fine"] == .passed)
        #expect(byName["alsoFine"] == .passed)
    }

    @Test("Failures do not leak into the next test")
    func failuresAreReset() throws {
        let results = try plugin("""
            @test func first() { expect(false); }
            @test func second() { expect(true); }
            """).runTests()
        #expect(outcomes(results) == ["first": .failed, "second": .passed])
        #expect(results.first { $0.test.name == "second" }?.diagnostics.isEmpty == true)
    }

    @Test("The filter matches the function name or the display name")
    func filtering() throws {
        let module = try plugin("""
            @test("alpha case") func a() { expect(true); }
            @test func beta() { expect(true); }
            """)
        #expect(module.runTests(matching: "alpha").map(\.test.name) == ["a"])
        #expect(module.runTests(matching: "beta").map(\.test.name) == ["beta"])
        #expect(module.runTests().count == 2)
    }

    @Test("A module loaded without tests has none to run")
    func productionHasNoTests() throws {
        let module = try AdaScriptPlugin(
            sources: [AdaScriptSource(path: "Main.ada", source: "@test func t() { expect(true); }")],
            name: "NoTests"
        )
        #expect(module.tests.isEmpty)
        #expect(module.runTests().isEmpty)
    }
}
