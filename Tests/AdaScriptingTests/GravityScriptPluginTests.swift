@testable import AdaApp
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

    @Test("Processes multiple ECS queries through indexed batches")
    @MainActor
    func processesMultipleQueryBatches() async throws {
        ScriptTransform.registerComponent()
        ScriptReadOnly.registerComponent()

        let source = """
        class BatchMovementSystem {
            func update(deltaTime, queries) {
                var transforms = queries[0];
                var readOnly = queries[1];
                var changed = 0;
                for (var index in 0..<transforms.count) {
                    var position = transforms.get(index, "ScriptTransform", "position");
                    position = [position[0] + 2, position[1], position[2]];
                    if (transforms.set(index, "ScriptTransform", "position", position)) {
                        changed += 1;
                    }
                }
                var denied = readOnly.set(0, "ScriptReadOnly", "value", 99);
                return [transforms.count, readOnly.count, changed, denied, transforms.id(0)];
            }
        }

        func main() {
            return AdaPlugin.create("BatchMovementPlugin", [
                AdaSystem.createBatch("batch.movement", "update", [
                    AdaQuery.write(["ScriptTransform"]),
                    AdaQuery.read(["ScriptReadOnly"])
                ], BatchMovementSystem())
            ]);
        }
        """

        let plugin = try GravityScriptPlugin(source: source)
        let world = World(name: "Script Batch Access Test")
        let firstEntity = world.spawn {
            ScriptTransform(position: Vector3(1, 2, 3))
            ScriptReadOnly(value: 7)
        }
        let secondEntity = world.spawn {
            ScriptTransform(position: Vector3(4, 5, 6))
            ScriptReadOnly(value: 8)
        }
        let app = AppWorlds(main: world)

        plugin.setup(in: app)
        await world.runScheduler(.update)

        #expect(plugin.descriptor.systems.first?.executionMode == .batch)
        #expect(world.get(ScriptTransform.self, from: firstEntity.id)?.position == Vector3(3, 2, 3))
        #expect(world.get(ScriptTransform.self, from: secondEntity.id)?.position == Vector3(6, 5, 6))
        #expect(world.get(ScriptReadOnly.self, from: firstEntity.id)?.value == 7)
        #expect(plugin.diagnostics.isEmpty)
        #expect(
            plugin.lastResult(for: "batch.movement") == .list([
                .integer(2),
                .integer(2),
                .integer(2),
                .boolean(false),
                .integer(Int64(firstEntity.id))
            ])
        )
    }

    @Test("Rejects invalid doubles before reflected integer writes")
    @MainActor
    func rejectsInvalidDoublesForIntegerFields() async throws {
        ScriptReadOnly.registerComponent()

        let source = """
        class InvalidIntegerSystem {
            func update(deltaTime, queries) {
                var entity = queries[0][0];
                var infinity = Float.max * Float.max;
                var notANumber = infinity - infinity;
                return [
                    entity.set("ScriptReadOnly", "value", Float.max),
                    entity.set("ScriptReadOnly", "value", infinity),
                    entity.set("ScriptReadOnly", "value", notANumber)
                ];
            }
        }

        func main() {
            return AdaPlugin.create("InvalidIntegerPlugin", [
                AdaSystem.create("invalid.integer", "update", [
                    AdaQuery.write(["ScriptReadOnly"])
                ], InvalidIntegerSystem())
            ]);
        }
        """
        let plugin = try GravityScriptPlugin(source: source)
        let world = World(name: "Invalid Gravity Integer Test")
        let entity = world.spawn {
            ScriptReadOnly(value: 7)
        }

        plugin.setup(in: AppWorlds(main: world))
        await world.runScheduler(.update)

        #expect(world.get(ScriptReadOnly.self, from: entity.id)?.value == 7)
        #expect(
            plugin.lastResult(for: "invalid.integer") == .list([
                .boolean(false),
                .boolean(false),
                .boolean(false)
            ])
        )
        #expect(plugin.diagnostics.count == 3)
        #expect(plugin.diagnostics.allSatisfy { $0 == "Invalid value for 'ScriptReadOnly.value'" })
    }

    @Test("Keeps separator-containing script system identities distinct")
    @MainActor
    func keepsScriptSystemIdentitiesDistinct() async throws {
        let firstPlugin = try GravityScriptPlugin(source: """
        class FirstSystem {
            func update(deltaTime, queries) { return 1; }
        }

        func main() {
            return AdaPlugin.create("A.B", [
                AdaSystem.create("C", "update", [], FirstSystem())
            ]);
        }
        """)
        let secondPlugin = try GravityScriptPlugin(source: """
        class SecondSystem {
            func update(deltaTime, queries) { return 2; }
        }

        func main() {
            return AdaPlugin.create("A", [
                AdaSystem.create("B.C", "update", [], SecondSystem())
            ]);
        }
        """)
        let world = World(name: "Gravity System Identity Test")
        let app = AppWorlds(main: world)

        firstPlugin.setup(in: app)
        secondPlugin.setup(in: app)
        await world.runScheduler(.update)

        #expect(firstPlugin.lastResult(for: "C") == .integer(1))
        #expect(secondPlugin.lastResult(for: "B.C") == .integer(2))
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
