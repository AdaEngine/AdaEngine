@testable import AdaApp
@_spi(Scripting) import AdaECS
import AdaScriptCompilerCore
@testable import AdaScripting
import Math
import Testing

@Suite("AdaScript structured schema fields", .serialized)
struct AdaScriptStructuredSchemaTests {
    private static let source = """
        enum Mode { idle, moving = 4, falling }

        @component(id: "game.body")
        struct Body {
            @export var position: Vector3 = Vector3(1, 2, 3);
            @export var size: Vector2 = Vector2(4, 5);
            @export var tint: Color = Color(0.25, 0.5, 0.75);
            @export var mode: Mode = Mode.moving;
            @export var target: Entity = null;
            @export var icon: Asset = "@res://Icons/body.png";
            @export var speed: Float = 2.5;
        }

        @resource(id: "game.settings")
        struct Settings {
            @export var gravity: Vector3 = Vector3.ZERO;
            @export var theme: Color = Color.white;
        }
        """

    @Test("Parses vector, color, enum, entity and asset defaults")
    func parsesStructuredFields() throws {
        let schemas = try AdaScriptSchemaParser.parse(sources: [AdaScriptCompilerSource(path: "Body.ada", source: Self.source)])
        let body = try #require(schemas.first { $0.name == "Body" })
        let fields = Dictionary(uniqueKeysWithValues: body.fields.map { ($0.name, $0.defaultValue) })

        #expect(fields["position"] == .vector([1, 2, 3]))
        #expect(fields["size"] == .vector([4, 5]))
        #expect(fields["tint"] == .color([0.25, 0.5, 0.75, 1]))
        #expect(fields["mode"] == .enumeration(type: "Mode", cases: ["idle", "moving", "falling"], selected: "moving"))
        #expect(fields["target"] == .entity)
        #expect(fields["icon"] == .asset(path: "@res://Icons/body.png"))
        #expect(fields["speed"] == .double(2.5))
        let settings = try #require(schemas.first { $0.name == "Settings" })
        #expect(settings.fields.map(\.defaultValue) == [.vector([0, 0, 0]), .color([1, 1, 1, 1])])
    }

    @Test("Rejects malformed structured defaults with a field-specific message")
    func rejectsMalformedDefaults() {
        func message(_ field: String, enumSource: String = "") -> String {
            do {
                _ = try AdaScriptSchemaParser.parse(sources: [
                    AdaScriptCompilerSource(path: "Bad.ada", source: "\(enumSource)\n@component(id: \"bad\")\nstruct Bad {\n    @export \(field)\n}")
                ])
                return ""
            } catch {
                return String(describing: error)
            }
        }
        #expect(message("var p: Vector3 = Vector3(1, 2);").contains("needs 3 components, found 2"))
        #expect(message("var p: Vector2 = 5;").contains("needs a Vector2(...) or [...] default"))
        #expect(message("var c: Color = Color.mauve;").contains("unknown Color constant 'mauve'"))
        #expect(message("var e: Entity = 3;").contains("must default to null"))
        #expect(message("var a: Asset = 3;").contains("null or an asset path"))
        #expect(message("var m: Mode = Mode.flying;", enumSource: "enum Mode { idle }").contains("has no case 'flying'"))
        #expect(message("var m: Mode = 3;", enumSource: "enum Mode { idle }").contains("must default to Mode.<case>"))
    }

    @Test("Structured values are rejected in network fields")
    func rejectsStructuredNetworkFields() {
        #expect(throws: (any Error).self) {
            _ = try AdaScriptSchemaParser.parse(sources: [
                AdaScriptCompilerSource(path: "Net.ada", source: """
                @replicated_component(id: "net.body", authority: "host")
                struct NetBody {
                    @export @network_field(tag: 1, mode: "state") var position: Vector3 = Vector3(0, 0, 0);
                }
                """)
            ])
        }
    }

    @Test("Duplicate or empty enums are reported")
    func rejectsInvalidEnums() {
        #expect(throws: AdaScriptSchemaError.self) {
            _ = try AdaScriptSchemaParser.parse(sources: [AdaScriptCompilerSource(path: "E.ada", source: "enum A { x, x }")])
        }
        #expect(throws: AdaScriptSchemaError.self) {
            _ = try AdaScriptSchemaParser.parse(sources: [AdaScriptCompilerSource(path: "E.ada", source: "enum A { }")])
        }
    }

    @Test("Scripts construct, read and write structured runtime component fields")
    @MainActor
    func scriptsUseStructuredFields() async throws {
        let plugin = try AdaScriptPlugin(
            sources: [AdaScriptSource(path: "Body.ada", source: Self.source + """

            var seenX = 0.0;

            @system(id: "bodies")
            class BodySystem {
                @query(Body)
                var bodies;

                func update(context) {
                    for (var row in bodies) {
                        seenX = row.body.position[0];
                        row.body.position = [9.0, 8.0, 7.0];
                        row.body.mode = "falling";
                        row.body.tint = [1.0, 0.0, 0.0];
                        row.body.target = 12;
                        row.body.icon = "@res://Icons/other.png";
                        row.body.mode = "flying";
                        row.body.size = [1.0, 2.0, 3.0];
                    }
                }
            }
            """)],
            name: "StructuredFields"
        )
        let world = World(name: "Structured fields")
        plugin.setup(in: AppWorlds(main: world))
        let descriptor = try #require(world.runtimeComponentDescriptor(named: "Body"))
        let entity = world.spawn(detachedComponents: [descriptor.makeDefault()])
        await world.runScheduler(.update)

        func field(_ name: String) -> ReflectedFieldValue? {
            descriptor.fields.first { $0.key == name }.flatMap {
                world.readComponentField(component: descriptor.componentID, entity: entity.id, field: $0)
            }
        }
        #expect(field("position") == .array([.double(9), .double(8), .double(7)]))
        #expect(field("mode") == .string("falling"))
        #expect(field("tint") == .object(["red": .double(1), "green": .double(0), "blue": .double(0), "alpha": .double(1)]))
        #expect(field("target") == .int(12))
        #expect(field("icon") == .string("@res://Icons/other.png"))
        #expect(field("size") == .array([.double(4), .double(5)]))
        #expect(plugin.diagnostics.first == "Invalid value for 'body.mode'")
    }

    @Test("Runtime descriptors expose editor kinds and validate writes")
    func descriptorKindsAndValidation() throws {
        let schemas = try AdaScriptSchemaParser.parse(sources: [AdaScriptCompilerSource(path: "Body.ada", source: Self.source)])
        let body = try #require(AdaScriptComponentRuntime.runtimeDescriptors(schemas: schemas).first { $0.name == "Body" })
        let kinds = Dictionary(uniqueKeysWithValues: body.fields.map { ($0.key, $0.kind) })

        #expect(kinds["position"] == .vector3)
        #expect(kinds["size"] == .vector2)
        #expect(kinds["tint"] == .color)
        #expect(kinds["mode"] == .enumeration(["idle", "moving", "falling"]))
        #expect(kinds["icon"] == .assetReference)
        #expect(kinds["target"] == .int)
        let position = try #require(body.fields.first { $0.key == "position" })
        #expect(position.accepts(.array([.int(1), .double(2), .double(3)])))
        #expect(!position.accepts(.array([.double(1), .double(2)])))
        #expect(!position.accepts(.array([.double(.nan), .double(2), .double(3)])))
        let mode = try #require(body.fields.first { $0.key == "mode" })
        #expect(mode.accepts(.string("idle")))
        #expect(!mode.accepts(.string("flying")))
        let tint = try #require(body.fields.first { $0.key == "tint" })
        #expect(tint.accepts(.array([.double(1), .double(0), .double(0)])))
        #expect(!tint.accepts(.array([.double(1)])))
    }
}
