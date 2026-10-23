@testable import AdaApp
@_spi(Scripting) import AdaECS
import AdaInput
import AdaScene
import AdaScripting
import Testing

/// Script-declared `@resource` structs and `@component` structs have no Swift type; systems and
/// scriptables reach them through runtime descriptors.
@MainActor
@Suite("AdaScript runtime declarations", .serialized)
struct AdaScriptRuntimeDeclarationTests {
    @Test("A system reads and writes a script @resource")
    func systemUsesScriptResource() async throws {
        let plugin = try AdaScriptPlugin(source: """
        @resource(id: "test.runtime.round-stats")
        struct RoundStats {
            @export var score = 10;
        }

        @system(id: "bump-round-stats")
        class BumpRoundStats {
            @res var stats: RoundStats;
            func update(context) { stats.score += 3; }
        }
        """, name: "RuntimeResourceSystem")
        let world = World(name: "Runtime resource")
        let app = AppWorlds(main: world)
        InputPlugin(actions: []).setup(in: app)
        plugin.setup(in: app)

        await world.runScheduler(.update)
        await world.runScheduler(.update)

        let store = try #require(world.getResource(RuntimeResourceStore.self))
        #expect(store.payloads["test.runtime.round-stats"]?.values == [.int(16)])
        #expect(plugin.diagnostics.isEmpty)
    }

    @Test("A scriptable binds a script @component")
    func scriptableBindsScriptComponent() async throws {
        let source = AdaScriptSource(path: "HudWriter.ada", source: """
        @component(id: "test.runtime.hud-state")
        struct HudState {
            @export var score = 0;
        }

        @scriptable(id: "test.runtime.hud-writer", version: 1)
        class HudWriter {
            @component(required: true) var state: HudState;
            func update(context) { state.score += 2; }
        }
        """)
        let schema = AdaScriptObjectSchema(
            identifier: "test.runtime.hud-writer",
            className: "HudWriter",
            version: 1,
            aliases: [],
            bindings: [
                AdaScriptObjectBinding(kind: .component(required: true), propertyName: "state", typeName: "HudState")
            ],
            fields: [:]
        )
        try AdaScriptObjectRegistration.register(schemas: [schema], sources: [source], moduleName: "HudWriter")
        let script = try ScriptableObjectRegistry.make(named: schema.identifier)
        let world = World(name: "Runtime component scriptable")
        let app = AppWorlds(main: world)
        InputPlugin(actions: []).setup(in: app)
        ScriptableObjectPlugin().setup(in: app)
        let plugin = try AdaScriptPlugin(sources: [source], name: "HudWriter")
        plugin.setup(in: app)
        let entity = world.spawn { ScriptableComponents(scripts: [script]) }
        #expect(world.insertDynamicComponent(named: "HudState", into: entity.id))

        await world.runScheduler(.update)
        await world.runScheduler(.update)

        #expect(world.dynamicComponentPayload(named: "HudState", of: entity.id)?["score"] == .int(4))
    }
}
