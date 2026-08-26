import AdaApp
import AdaECS
import AdaScripting
import Foundation
import Testing

@Suite("Gravity script plugins", .serialized)
struct GravityScriptPluginTests {
    @Test("Loads a script file with multiple ECS queries")
    @MainActor
    func loadsFileWithMultipleQueries() async throws {
        ScriptPosition.registerComponent()
        ScriptVelocity.registerComponent()

        let source = """
        class QueryProbeSystem {
            func update(deltaTime, queries) {
                return [queries[0].count, queries[1].count];
            }
        }

        class PositionCountSystem {
            func update(deltaTime, queries) {
                return queries[0].count;
            }
        }

        func main() {
            return AdaPlugin.create("QueryPlugin", [
                AdaSystem.create("query.probe", "update", [
                    AdaQuery.read(["ScriptPosition", "ScriptVelocity"]),
                    AdaQuery.read(["ScriptPosition"])
                ], QueryProbeSystem()),
                AdaSystem.create("position.count", "update", [
                    AdaQuery.read(["ScriptPosition"])
                ], PositionCountSystem())
            ]);
        }
        """
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AdaScripting-\(UUID().uuidString).gravity")
        try source.write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let plugin = try GravityScriptPlugin(contentsOf: fileURL)
        let world = World(name: "Script Test")
        world.spawn {
            ScriptPosition()
            ScriptVelocity()
        }
        world.spawn {
            ScriptPosition()
        }
        let app = AppWorlds(main: world)

        plugin.setup(in: app)
        await world.runScheduler(.update)

        #expect(plugin.descriptor.name == "QueryPlugin")
        #expect(plugin.descriptor.systems.count == 2)
        #expect(plugin.descriptor.systems.first?.queries.count == 2)
        #expect(
            plugin.lastResult(for: "query.probe") == .list([
                .integer(1),
                .integer(2)
            ])
        )
        #expect(plugin.lastResult(for: "position.count") == .integer(2))
    }

    @Test("Rejects an unknown native component")
    func rejectsUnknownComponent() throws {
        let source = """
        class BrokenSystem {
            func update(deltaTime, queries) {}
        }

        func main() {
            return AdaPlugin.create("BrokenPlugin", [
                AdaSystem.create("broken", "update", [
                    AdaQuery.read(["MissingComponent"])
                ], BrokenSystem())
            ]);
        }
        """

        #expect(throws: GravityScriptError.self) {
            try GravityScriptPlugin(source: source)
        }
    }
}

private struct ScriptPosition: Component {}
private struct ScriptVelocity: Component {}
