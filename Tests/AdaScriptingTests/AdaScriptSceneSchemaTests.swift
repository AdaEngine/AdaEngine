@_spi(Scripting) import AdaECS
import AdaScriptCompilerCore
@testable import AdaScripting
import Foundation
import Testing

@Suite("AdaScript scene schema identity", .serialized)
struct AdaScriptSceneSchemaTests {
    private static let source = """
        enum Mode { idle, moving }

        @component(id: "game.body", aliases: ["OldBody", "game.legacy_body"])
        struct Body {
            @export var count: Int = 1;
            @export var position: Vector3 = Vector3(0, 0, 0);
            @export var mode: Mode = Mode.idle;
            @export var tint: Color = Color.white;
        }
        """

    private func schemas() throws -> [AdaScriptDataSchema] {
        try AdaScriptSchemaParser.parse(sources: [AdaScriptCompilerSource(path: "Body.ada", source: Self.source)])
    }

    @Test("Aliases resolve to the stable ID and must not collide")
    func aliasesResolveAndAreUnique() throws {
        let schemas = try schemas()
        #expect(schemas.first?.aliases == ["OldBody", "game.legacy_body"])
        #expect(AdaScriptSceneSchemaResolver.resolve(key: "game.body", in: schemas)?.match == .stableID)
        #expect(AdaScriptSceneSchemaResolver.resolve(key: "Body", in: schemas)?.match == .name)
        #expect(AdaScriptSceneSchemaResolver.resolve(key: "OldBody", in: schemas)?.match == .alias)
        #expect(AdaScriptSceneSchemaResolver.resolve(key: "OldBody", in: schemas)?.canonicalKey == "game.body")
        #expect(AdaScriptSceneSchemaResolver.resolve(key: "Missing", in: schemas) == nil)

        #expect(throws: AdaScriptSchemaError.self) {
            _ = try AdaScriptSchemaParser.parse(sources: [AdaScriptCompilerSource(path: "Clash.ada", source: """
            @component(id: "a.one", aliases: ["Two"])
            struct One { @export var x: Int = 0; }
            @component(id: "a.two")
            struct Two { @export var x: Int = 0; }
            """)])
        }
        #expect(throws: (any Error).self) {
            _ = try AdaScriptSchemaParser.parse(sources: [AdaScriptCompilerSource(path: "Dup.ada", source: """
            @component(id: "a.one", aliases: ["Same", "Same"])
            struct One { @export var x: Int = 0; }
            """)])
        }
    }

    @Test("Diagnostics distinguish renames, removed fields, new fields, and type errors")
    func migrationDiagnostics() throws {
        let schemas = try schemas()
        let current = AdaScriptSceneSchemaResolver.diagnose(
            key: "game.body",
            fields: ["count": 3, "position": [1, 2, 3], "mode": "moving", "tint": ["red": 1, "green": 0, "blue": 0]],
            schemas: schemas
        )
        #expect(current.isEmpty)

        let stale = AdaScriptSceneSchemaResolver.diagnose(
            key: "OldBody",
            fields: ["count": 3, "position": [1, 2, 3], "mode": "moving", "legacy": 1],
            schemas: schemas
        )
        #expect(stale.contains { $0.severity == .warning && $0.message.contains("store the stable ID 'game.body'") })
        #expect(stale.contains { $0.message.contains("saved field 'legacy' no longer exists") })
        #expect(stale.contains { $0.message.contains("field 'tint' is not in the saved scene") })
        #expect(stale.allSatisfy { $0.severity == .warning })

        let broken = AdaScriptSceneSchemaResolver.diagnose(
            key: "game.body",
            fields: ["count": 1.5, "position": [1, 2], "mode": "flying", "tint": "red"],
            schemas: schemas
        )
        let errors = broken.filter { $0.severity == .error }.map(\.message)
        #expect(errors.count == 4)
        #expect(errors.contains { $0.contains("'count' is not an integer") })
        #expect(errors.contains { $0.contains("'position' is not a list of 3 numbers") })
        #expect(errors.contains { $0.contains("'mode' is not a case of Mode") })
        #expect(errors.contains { $0.contains("'tint' is not a color") })

        let unknown = AdaScriptSceneSchemaResolver.diagnose(key: "ghost", fields: [:], schemas: schemas)
        #expect(unknown.first?.severity == .error)
    }

    @Test("A scene component decodes into a validated runtime payload, by alias")
    @MainActor
    func decodesSceneComponent() throws {
        let descriptors = AdaScriptComponentRuntime.runtimeDescriptors(schemas: try schemas())
        let descriptor = try #require(descriptors.first)
        let world = World(name: "Scene decode")
        world.registerRuntimeComponent(descriptor)
        #expect(world.runtimeComponentDescriptor(named: "OldBody")?.componentID == descriptor.componentID)
        #expect(world.runtimeComponentDescriptor(named: "game.legacy_body")?.componentID == descriptor.componentID)

        let payload = try AdaScriptSceneComponentDecoder.decode(
            ["count": 5, "position": [1, 2, 3], "mode": "moving", "tint": ["red": 0.5, "green": 0.25, "blue": 1]],
            as: descriptor
        )
        #expect(payload.values[0] == .int(5))
        #expect(payload.values[1] == .array([.double(1), .double(2), .double(3)]))
        #expect(payload.values[2] == .string("moving"))
        #expect(payload.values[3] == .object(["red": .double(0.5), "green": .double(0.25), "blue": .double(1), "alpha": .double(1)]))

        let partial = try AdaScriptSceneComponentDecoder.decode(["count": 9], as: descriptor)
        #expect(partial.values[0] == .int(9))
        #expect(partial.values[2] == .string("idle"))

        #expect(throws: AdaScriptError.self) { try AdaScriptSceneComponentDecoder.decode(["mode": "flying"], as: descriptor) }
        #expect(throws: AdaScriptError.self) { try AdaScriptSceneComponentDecoder.decode(["position": [1, 2]], as: descriptor) }
        #expect(throws: AdaScriptError.self) { try AdaScriptSceneComponentDecoder.decode(["count": true], as: descriptor) }
    }
}

#if canImport(GravityAOT)
extension AdaScriptSceneSchemaTests {
    @Test("A native scene loads a component saved under a former alias and reports the migration")
    @MainActor
    func nativeSceneLoadsAliasedComponent() throws {
        let schemas = try schemas()
        let descriptors = AdaScriptComponentRuntime.runtimeDescriptors(schemas: schemas)
        let descriptor = try #require(descriptors.first)
        let data = try JSONSerialization.data(withJSONObject: ["count": 4, "position": [1, 2, 3], "mode": "moving", "removed": 1])
        let document = AdaScriptNativeSceneDocument(
            name: "Aliased",
            entities: [.init(id: "body", name: "Body", enabled: true, parent: nil, components: ["OldBody": data])]
        )

        let scene = try document.makeScene(components: descriptors)
        let entity = try #require(scene.world.getEntityByName("Body"))
        let payload = try #require(scene.world.getRuntimeComponent(descriptor.componentID, from: entity.id))
        #expect(payload.values[0] == .int(4))
        #expect(payload.values[2] == .string("moving"))

        let diagnostics = document.migrationDiagnostics(schemas: schemas)
        #expect(diagnostics.contains { $0.message.contains("store the stable ID 'game.body'") })
        #expect(diagnostics.contains { $0.message.contains("saved field 'removed' no longer exists") })
        #expect(diagnostics.allSatisfy { $0.severity == .warning })
    }
}
#endif
