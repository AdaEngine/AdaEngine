@testable import AdaApp
import AdaECS
import AdaScripting
import AdaUtils
import Math
import Testing

extension GravityScriptPluginTests {
    @Test("Reports an unknown native component during plugin setup")
    @MainActor
    func reportsUnknownComponentDuringSetup() async throws {
        let plugin = try GravityScriptPlugin(source: Self.missingComponentSource)
        let app = AppWorlds(main: World(name: "Missing Component Test"))
        app.addPlugin(plugin)

        try await app.build()

        #expect(plugin.diagnostics == ["Unknown component 'MissingComponent' in query 0 of system 'broken'"])
    }

    @Test("Resolves components registered by an earlier plugin setup")
    @MainActor
    func resolvesComponentsDuringOrderedPluginSetup() async throws {
        let plugin = try GravityScriptPlugin(source: Self.deferredComponentSource)
        let world = World(name: "Deferred Component Registration Test")
        world.spawn { DeferredScriptComponent() }
        let app = AppWorlds(main: world)
        app.addPlugin(DeferredComponentRegistrationPlugin())
        app.addPlugin(plugin)

        try await app.build()
        await world.runScheduler(.update)

        #expect(plugin.diagnostics.isEmpty)
        #expect(plugin.lastResult(for: "deferred") == .integer(1))
    }

    @Test("Rejects non-finite and out-of-range floating-point writes")
    @MainActor
    func rejectsInvalidFloatingPointWrites() async throws {
        ScriptNumericFields.registerComponent()
        let plugin = try GravityScriptPlugin(source: Self.invalidFloatSource)
        let world = World(name: "Invalid Gravity Float Test")
        let entity = world.spawn {
            ScriptNumericFields(
                scalar: 1,
                vector: Vector2(2, 3),
                quaternion: Quat(x: 0, y: 0, z: 0, w: 1),
                color: .white,
                double: 5
            )
        }

        plugin.setup(in: AppWorlds(main: world))
        await world.runScheduler(.update)

        let fields = try #require(world.get(ScriptNumericFields.self, from: entity.id))
        #expect(fields.scalar == 1)
        #expect(fields.vector == Vector2(2, 3))
        #expect(fields.quaternion == Quat(x: 0, y: 0, z: 0, w: 1))
        #expect(fields.color == .white)
        #expect(fields.double == 42)
        #expect(
            plugin.lastResult(for: "invalid.float") == .list([
                .boolean(false),
                .boolean(false),
                .boolean(false),
                .boolean(false),
                .boolean(true)
            ])
        )
        #expect(plugin.diagnostics.count == 4)
    }

    @Test("Rejects a list when any member is unsupported")
    @MainActor
    func rejectsUnsupportedListMembersAtomically() async throws {
        ScriptNumericFields.registerComponent()
        let plugin = try GravityScriptPlugin(source: Self.unsupportedListMemberSource)
        let world = World(name: "Unsupported Gravity List Member Test")
        let entity = world.spawn {
            ScriptNumericFields(
                scalar: 1,
                vector: Vector2(2, 3),
                quaternion: Quat(x: 0, y: 0, z: 0, w: 1),
                color: .white,
                double: 5
            )
        }

        plugin.setup(in: AppWorlds(main: world))
        await world.runScheduler(.update)

        #expect(world.get(ScriptNumericFields.self, from: entity.id)?.vector == Vector2(2, 3))
        #expect(plugin.lastResult(for: "invalid.list") == .boolean(false))
        #expect(plugin.diagnostics == ["Unsupported value for 'ScriptNumericFields.vector'"])
    }

    private static let missingComponentSource = """
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

    private static let deferredComponentSource = """
    class DeferredSystem {
        func update(deltaTime, queries) {
            return queries[0].count;
        }
    }

    func main() {
        return AdaPlugin.create("DeferredPlugin", [
            AdaSystem.create("deferred", "update", [
                AdaQuery.read(["DeferredScriptComponent"])
            ], DeferredSystem())
        ]);
    }
    """

    private static let invalidFloatSource = """
    class InvalidFloatSystem {
        func update(deltaTime, queries) {
            var entity = queries[0][0];
            var infinity = Float.max * Float.max;
            var notANumber = infinity - infinity;
            return [
                entity.set("ScriptNumericFields", "scalar", Float.max),
                entity.set("ScriptNumericFields", "vector", [1, infinity]),
                entity.set("ScriptNumericFields", "quaternion", [0, 0, notANumber, 1]),
                entity.set("ScriptNumericFields", "color", [1, 1, 1, infinity]),
                entity.set("ScriptNumericFields", "double", 42)
            ];
        }
    }

    func main() {
        return AdaPlugin.create("InvalidFloatPlugin", [
            AdaSystem.create("invalid.float", "update", [
                AdaQuery.write(["ScriptNumericFields"])
            ], InvalidFloatSystem())
        ]);
    }
    """

    private static let unsupportedListMemberSource = """
    class UnsupportedValue {}

    class InvalidListSystem {
        func update(deltaTime, queries) {
            var entity = queries[0][0];
            return entity.set("ScriptNumericFields", "vector", [UnsupportedValue(), 3, 4]);
        }
    }

    func main() {
        return AdaPlugin.create("InvalidListPlugin", [
            AdaSystem.create("invalid.list", "update", [
                AdaQuery.write(["ScriptNumericFields"])
            ], InvalidListSystem())
        ]);
    }
    """
}

private struct DeferredScriptComponent: Component {}

private struct DeferredComponentRegistrationPlugin: Plugin {
    @MainActor
    func setup(in app: borrowing AppWorlds) {
        DeferredScriptComponent.registerComponent()
    }
}

@Component
private struct ScriptNumericFields: Codable, Sendable {
    var scalar: Float
    var vector: Vector2
    var quaternion: Quat
    var color: Color
    var double: Double
}
