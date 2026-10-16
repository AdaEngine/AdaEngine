import AdaScriptCompilerCore
@testable import AdaScripting
import Testing

@Suite("AdaScript @test annotation", .serialized)
struct AdaScriptTestAnnotationTests {
    private static let gameplay = """
        @system(id: "move")
        class Move {
            func update(context) {}
        }

        private func clampVelocity(v) {
            return v;
        }

        @test("clamp caps speed")
        func clampCaps() {
            expectEqual(clampVelocity(999), 10);
        }

        @test
        func plainName() {
            expect(true);
        }
        """

    private func resolve(_ source: String, path: String = "Main.ada", includeTests: Bool = false) throws -> ResolvedGravityScriptModule {
        try GravityScriptModuleResolver.resolve([AdaScriptSource(path: path, source: source)], includeTests: includeTests)
    }

    private func failure(_ source: String, includeTests: Bool = false) -> String {
        do {
            _ = try resolve(source, includeTests: includeTests)
            return ""
        } catch {
            return String(describing: error)
        }
    }

    @Test("@test is a known annotation that applies to functions only")
    func catalogRule() {
        let rule = AdaScriptAnnotationCatalog.rules["test"]
        #expect(rule?.targets == [.function])
        let message = failure("""
            @test class Oops {}
            """)
        #expect(message.contains("Main.ada:1:1: @test cannot annotate a class; it applies to a function"))
    }

    @Test("Syntax tree lists top-level tests with display names")
    func discovery() {
        let tree = AdaScriptSyntax.parse(source: Self.gameplay, path: "Main.ada")
        #expect(tree.tests.map(\.name) == ["clampCaps", "plainName"])
        #expect(tree.tests.map(\.displayName) == ["clamp caps speed", "plainName"])
        #expect(tree.tests.allSatisfy { $0.parameterCount == 0 })
    }

    @Test("Methods are not discovered as tests and are diagnosed")
    func methodsAreRejected() {
        let source = """
            @system(id: "s")
            class S {
                @test func inside() {}
                func update(context) {}
            }
            """
        #expect(AdaScriptSyntax.parse(source: source, path: "Main.ada").tests.isEmpty)
        #expect(failure(source).contains("Main.ada:3:5: @test cannot annotate a method; it applies to a function"))
    }

    @Test("A test cannot take parameters")
    func parametersAreRejected() {
        let message = failure("""
            @test
            func broken(world) {}
            """)
        #expect(message.contains("Main.ada:1:1: @test function 'broken' cannot take parameters"))
    }

    @Test("Production modules drop tests and keep line numbers")
    func productionStripsTests() throws {
        let production = try resolve(Self.gameplay)
        #expect(!production.combinedSource.contains("clampCaps"))
        #expect(!production.combinedSource.contains("expectEqual"))
        #expect(production.combinedSource.contains("clampVelocity"))

        let withTests = try resolve(Self.gameplay, includeTests: true)
        #expect(withTests.combinedSource.contains("clampCaps"))

        let tree = AdaScriptSyntax.parse(source: Self.gameplay, path: "Main.ada")
        let stripped = AdaScriptImportLowering.lower(source: Self.gameplay, tree: tree, stripTests: true)
        #expect(stripped.count == Self.gameplay.count)
        #expect(stripped.filter { $0 == "\n" }.count == Self.gameplay.filter { $0 == "\n" }.count)
    }

    @Test("Production code cannot reference test-only names")
    func productionLeaks() {
        let message = failure("""
            @system(id: "s")
            class S {
                func update(context) {
                    expect(true);
                }
            }
            @test func covers() {}
            func helper() { covers(); }
            """)
        #expect(message.contains("Main.ada:4:9: 'expect' is test-only and cannot be used outside @test functions"))
        #expect(message.contains("Main.ada:8:17: 'covers' is test-only and cannot be used outside @test functions"))
    }

    @Test("A project's own helper named like the test API is not a leak")
    func ownDeclarationIsNotALeak() throws {
        let module = try resolve("""
            func fail(message) { return message; }
            @system(id: "s")
            class S {
                func update(context) { fail("x"); }
            }
            """)
        #expect(module.combinedSource.contains("fail"))
    }
}
