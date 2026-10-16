import AdaScriptCompilerCore
@testable import AdaScripting
import Testing

@Suite("AdaScript TestWorld", .serialized)
struct AdaScriptTestWorldTests {
    private static let gameplay = """
        @component(id: "test.body")
        struct Body {
            @export var y = 10.0;
            @export var speed = 0.0;
        }

        @system(id: "test.gravity")
        class GravitySystem {
            @query(Body)
            var bodies;

            func update(context) {
                for (var entity in bodies) {
                    entity.body.speed = entity.body.speed - 9.8 * context.deltaTime;
                    entity.body.y = entity.body.y + entity.body.speed * context.deltaTime;
                }
            }
        }
        """

    private func results(_ tests: String) throws -> [String: AdaScriptTestResult] {
        let plugin = try AdaScriptPlugin(
            sources: [AdaScriptSource(path: "Main.ada", source: Self.gameplay + "\n" + tests)],
            name: "TestWorldTests",
            includeTests: true
        )
        let results = plugin.runTests()
        #expect(plugin.diagnostics.isEmpty, "\(plugin.diagnostics)")
        return Dictionary(uniqueKeysWithValues: results.map { ($0.test.name, $0) })
    }

    @Test("A test spawns entities, runs systems and reads the result")
    func runsSystems() throws {
        let byName = try results("""
            @test("bodies fall")
            func falls() {
                var world = TestWorld();
                var body = world.spawn([Body(y: 10.0, speed: 0.0)]);
                expect(world.has(body, "Body"));
                expectEqual(world.read(body, "Body", "y"), 10.0);
                world.run(30);
                expect(world.read(body, "Body", "y") < 10.0);
                expect(world.read(body, "Body", "speed") < 0.0);
            }
            """)
        let falls = try #require(byName["falls"])
        #expect(falls.diagnostics.isEmpty, "\(falls.diagnostics)")
        #expect(falls.outcome == .passed)
    }

    @Test("Each test gets a fresh world")
    func worldsAreIsolated() throws {
        let byName = try results("""
            @test func first() {
                var world = TestWorld();
                world.spawn([Body()]);
                world.spawn([Body()]);
                expectEqual(world.count("Body"), 2);
            }
            @test func second() {
                var world = TestWorld();
                expectEqual(world.count("Body"), 0);
                world.spawn([Body()]);
                expectEqual(world.count("Body"), 1);
            }
            """)
        for name in ["first", "second"] {
            let result = try #require(byName[name])
            #expect(result.outcome == .passed, "\(name): \(result.diagnostics)")
        }
    }

    @Test("advance moves time by an exact step and despawn removes the entity")
    func advanceAndDespawn() throws {
        let byName = try results("""
            @test func exactStep() {
                var world = TestWorld();
                var body = world.spawn([Body(y: 0.0, speed: 10.0)]);
                world.advance(0.5);
                expectNear(world.read(body, "Body", "y"), 10.0 * 0.5 - 9.8 * 0.5 * 0.5, 0.01);
            }
            @test func despawns() {
                var world = TestWorld();
                var body = world.spawn([Body()]);
                expect(world.despawn(body));
                expectEqual(world.count("Body"), 0);
            }
            """)
        for name in ["exactStep", "despawns"] {
            let result = try #require(byName[name])
            #expect(result.outcome == .passed, "\(name): \(result.diagnostics)")
        }
    }

    @Test("A failing expectation after run is still reported")
    func failureAfterRun() throws {
        let byName = try results("""
            @test func failsLate() {
                var world = TestWorld();
                var body = world.spawn([Body(y: 10.0, speed: 0.0)]);
                world.run(5);
                expect(world.read(body, "Body", "y") > 10.0);
            }
            @test func stillRuns() { expect(true); }
            """)
        #expect(byName["failsLate"]?.outcome == .failed)
        #expect(byName["stillRuns"]?.outcome == .passed)
    }
}
