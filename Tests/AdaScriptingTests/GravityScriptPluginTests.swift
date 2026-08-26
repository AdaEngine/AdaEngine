import AdaApp
import AdaECS
import AdaScripting
import Foundation
import Math
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

    @Test("Reads and writes reflected component fields")
    @MainActor
    func readsAndWritesReflectedFields() async throws {
        ScriptTransform.registerComponent()
        ScriptReadOnly.registerComponent()

        let source = """
        class MovementSystem {
            func update(deltaTime, queries) {
                var entity = queries[0][0];
                var position = entity.get("ScriptTransform", "position");
                position = [position[0] + 5, position[1], position[2]];
                var changed = entity.set("ScriptTransform", "position", position);
                var denied = entity.set("ScriptReadOnly", "value", 99);
                return [entity.id, changed, denied, entity.get("ScriptTransform", "position")];
            }
        }

        func main() {
            return AdaPlugin.create("MovementPlugin", [
                AdaSystem.create("movement", "update", [
                    AdaQuery.readWrite(
                        ["ScriptTransform", "ScriptReadOnly"],
                        ["ScriptTransform"]
                    )
                ], MovementSystem())
            ]);
        }
        """

        let plugin = try GravityScriptPlugin(source: source)
        let world = World(name: "Script Component Access Test")
        let entity = world.spawn {
            ScriptTransform(position: Vector3(1, 2, 3))
            ScriptReadOnly(value: 7)
        }
        let app = AppWorlds(main: world)

        plugin.setup(in: app)
        await world.runScheduler(.update)

        let transform = try #require(world.get(ScriptTransform.self, from: entity.id))
        let readOnly = try #require(world.get(ScriptReadOnly.self, from: entity.id))
        #expect(plugin.diagnostics.isEmpty)
        #expect(transform.position == Vector3(6, 2, 3))
        #expect(readOnly.value == 7)
        #expect(
            plugin.lastResult(for: "movement") == .list([
                .integer(Int64(entity.id)),
                .boolean(true),
                .boolean(false),
                .list([.double(6), .double(2), .double(3)])
            ])
        )
    }
}

private struct ScriptPosition: Component {}
private struct ScriptVelocity: Component {}

@Component
private struct ScriptTransform: Codable, Sendable {
    var position: Vector3
}

@Component
private struct ScriptReadOnly: Codable, Sendable {
    var value: Int
}
