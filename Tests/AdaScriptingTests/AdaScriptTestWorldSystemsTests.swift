import AdaScriptCompilerCore
@testable import AdaScripting
import Testing

@Suite("AdaScript TestWorld systems and globals", .serialized)
struct AdaScriptTestWorldSystemsTests {
    private static let gameplay = """
        @component(id: "test.counter")
        struct Counter {
            @export var a = 0;
            @export var b = 0;
        }

        var ticksSeen = 0;
        var label = "start";

        @system(id: "test.first")
        class FirstSystem {
            @query(Counter)
            var rows;

            func update(context) {
                ticksSeen = ticksSeen + 1;
                for (var entity in rows) { entity.counter.a = entity.counter.a + 1; }
            }
        }

        @system(id: "test.second")
        class SecondSystem {
            @query(Counter)
            var rows;

            func update(context) {
                for (var entity in rows) { entity.counter.b = entity.counter.b + 1; }
            }
        }
        """

    private func results(_ tests: String) throws -> [String: AdaScriptTestResult] {
        let plugin = try AdaScriptPlugin(
            sources: [AdaScriptSource(path: "Main.ada", source: Self.gameplay + "\n" + tests)],
            name: "SystemsTests",
            includeTests: true
        )
        let results = plugin.runTests()
        #expect(plugin.diagnostics.isEmpty, "\(plugin.diagnostics)")
        return Dictionary(uniqueKeysWithValues: results.map { ($0.test.name, $0) })
    }

    @Test("runSystem installs only the named system")
    func runsOneSystem() throws {
        let byName = try results("""
            @test func onlyFirst() {
                var world = TestWorld();
                var row = world.spawn([Counter()]);
                world.runSystem(FirstSystem, 3);
                expectEqual(world.read(row, "Counter", "a"), 3);
                expectEqual(world.read(row, "Counter", "b"), 0);
            }
            @test func byName() {
                var world = TestWorld();
                var row = world.spawn([Counter()]);
                world.runSystem("SecondSystem", 2);
                expectEqual(world.read(row, "Counter", "a"), 0);
                expectEqual(world.read(row, "Counter", "b"), 2);
            }
            @test func systemsAccumulate() {
                var world = TestWorld();
                var row = world.spawn([Counter()]);
                world.runSystem(FirstSystem, 1);
                world.runSystem(SecondSystem, 1);
                expectEqual(world.read(row, "Counter", "a"), 2);
                expectEqual(world.read(row, "Counter", "b"), 1);
            }
            @test func runInstallsEverything() {
                var world = TestWorld();
                var row = world.spawn([Counter()]);
                world.run(2);
                expectEqual(world.read(row, "Counter", "a"), 2);
                expectEqual(world.read(row, "Counter", "b"), 2);
            }
            """)
        for name in ["onlyFirst", "byName", "systemsAccumulate", "runInstallsEverything"] {
            let result = try #require(byName[name])
            #expect(result.outcome == .passed, "\(name): \(result.diagnostics)")
        }
    }

    @Test("Startup systems run once before the first update")
    func startupSystemsRun() throws {
        let plugin = try AdaScriptPlugin(
            sources: [
                AdaScriptSource(path: "Main.ada", source: """
                    @component(id: "test.marker")
                    struct Marker { @export var value = 0; }

                    @system(id: "test.bootstrap", scheduler: "startup")
                    class BootstrapSystem {
                        func update(context) { context.world.spawn([Marker(value: 7)]); }
                    }

                    @test func spawnsOnce() {
                        var world = TestWorld();
                        expectEqual(world.count("Marker"), 0);
                        world.run(3);
                        expectEqual(world.count("Marker"), 1);
                    }
                    """),
            ],
            name: "StartupTest",
            includeTests: true
        )
        let results = plugin.runTests()
        #expect(results.map(\.outcome) == [.passed], "\(results.map(\.diagnostics))")
    }

    @Test("Module-level variables are restored between tests")
    func globalsAreRestored() throws {
        let byName = try results("""
            @test func mutates() {
                var world = TestWorld();
                world.spawn([Counter()]);
                world.run(4);
                expectEqual(ticksSeen, 4);
                label = "changed";
            }
            @test func seesOriginal() {
                expectEqual(ticksSeen, 0);
                expectEqual(label, "start");
            }
            """)
        for name in ["mutates", "seesOriginal"] {
            let result = try #require(byName[name])
            #expect(result.outcome == .passed, "\(name): \(result.diagnostics)")
        }
    }
}
