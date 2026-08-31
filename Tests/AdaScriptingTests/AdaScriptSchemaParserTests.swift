import AdaScriptCompilerCore
import Testing

@Suite("Ada Script schema parser")
struct AdaScriptSchemaParserTests {
    @Test("Parses component and resource primitive schemas")
    func parsesPrimitiveSchemas() throws {
        let schemas = try AdaScriptSchemaParser.parse(sources: [
            AdaScriptCompilerSource(
                path: "Data.ada",
                source: """
                @component(id: "game.health")
                struct Health {
                    @export var current = 100.0;
                    @export var maximum = 120;
                    @export var title = "Player";
                    @export var enabled = true;
                }

                @resource(id: "game.balance", autoInsert: true)
                struct GameBalance {
                    @export var gravity = 9.8;
                }
                """
            )
        ])

        #expect(schemas.count == 2)
        #expect(schemas[0].name == "Health")
        #expect(schemas[0].id == "game.health")
        #expect(schemas[0].kind == .component)
        #expect(schemas[0].fields.map(\.defaultValue) == [
            .double(100),
            .int(120),
            .string("Player"),
            .bool(true)
        ])
        #expect(schemas[1].kind == .resource(autoInsert: true))
    }

    @Test("Rejects duplicate stable identifiers")
    func rejectsDuplicateIDs() {
        #expect(throws: AdaScriptSchemaError.duplicateID("game.data")) {
            try AdaScriptSchemaParser.parse(sources: [
                AdaScriptCompilerSource(
                    path: "A.ada",
                    source: "@component(id: \"game.data\") struct A { @export var value = 1; }"
                ),
                AdaScriptCompilerSource(
                    path: "B.ada",
                    source: "@resource(id: \"game.data\") struct B { @export var value = 2; }"
                )
            ])
        }
    }

    @Test("Rejects fields without stable defaults")
    func rejectsUnsupportedDefaults() {
        #expect(throws: AdaScriptSchemaError.self) {
            try AdaScriptSchemaParser.parse(sources: [
                AdaScriptCompilerSource(
                    path: "Bad.ada",
                    source: "@component(id: \"bad\") struct Bad { @export var value = []; }"
                )
            ])
        }
    }

    @Test("Parses typed resource bindings from systems")
    func parsesResourceBindings() throws {
        let bindings = try AdaScriptSchemaParser.parseResourceBindings(sources: [
            AdaScriptCompilerSource(
                path: "Systems.ada",
                source: """
                @system
                class BalanceSystem {
                    @res
                    var balance: GameBalance;

                    @res(optional: true)
                    var debug: DebugSettings;

                    func update(context) {}
                }
                """
            )
        ])

        #expect(bindings == [
            AdaScriptResourceBinding(
                isOptional: false,
                propertyName: "balance",
                resourceName: "GameBalance",
                systemName: "BalanceSystem"
            ),
            AdaScriptResourceBinding(
                isOptional: true,
                propertyName: "debug",
                resourceName: "DebugSettings",
                systemName: "BalanceSystem"
            )
        ])
    }

    @Test("Infers deferred commands only for systems that use WorldContext")
    func parsesSystemCapabilities() throws {
        let capabilities = try AdaScriptSchemaParser.parseSystemCapabilities(sources: [
            AdaScriptCompilerSource(
                path: "Systems.ada",
                source: """
                @system
                class CleanupSystem {
                    func update(context) {
                        context.world.commands.despawn(42);
                    }
                }

                @system
                class ReadOnlySystem {
                    func update(context) {}
                }
                """
            )
        ])

        #expect(capabilities == [
            AdaScriptSystemCapabilities(systemName: "CleanupSystem", usesDeferredCommands: true),
            AdaScriptSystemCapabilities(systemName: "ReadOnlySystem", usesDeferredCommands: false)
        ])
    }

    @Test("Parses scriptable identity, aliases, version, and exported state")
    func parsesScriptables() throws {
        let schemas = try AdaScriptSchemaParser.parseScriptables(sources: [
            AdaScriptCompilerSource(
                path: "Player.ada",
                source: """
                @scriptable(
                    id: "game.player-controller",
                    version: 2,
                    aliases: ["PlayerController", "game.player"]
                )
                class PlayerController {
                    @export var speed = 8.0;
                    @component(required: true) var transform: Transform;
                    @res(optional: true) var input: Input;
                    var runtimeCache = 0;

                    func update(context) {
                        runtimeCache += 1;
                    }
                }
                """
            )
        ])

        #expect(schemas == [
            AdaScriptableSchema(
                aliases: ["PlayerController", "game.player"],
                bindings: [
                    AdaScriptableBinding(
                        kind: .component(required: true),
                        propertyName: "transform",
                        typeName: "Transform"
                    ),
                    AdaScriptableBinding(
                        kind: .resource(optional: true),
                        propertyName: "input",
                        typeName: "Input"
                    )
                ],
                fields: [AdaScriptSchemaField(defaultValue: .double(8), name: "speed")],
                id: "game.player-controller",
                name: "PlayerController",
                sourcePath: "Player.ada",
                version: 2
            )
        ])
    }
}
