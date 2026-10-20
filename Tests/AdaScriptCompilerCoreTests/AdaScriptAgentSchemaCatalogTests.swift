import AdaScriptCompilerCore
import Foundation
import Testing

@Suite("Agent source schema catalog")
struct AdaScriptAgentSchemaCatalogTests {
    @Test func describesComponentsAndResourcesWithoutLoadingAScene() throws {
        let source = AdaScriptCompilerSource(path: "Sources/Player.ada", source: """
            enum Mode { idle, walking }
            @component(id: "game.player", aliases: ["OldPlayer"])
            struct Player {
                @export var health = 100;
                @export var speed = 3.0;
                @export var active = true;
                @export var title = "Player";
                @export var position: Vector3 = Vector3(0, 1, 0);
                @export var tint: Color = Color(1, 0.5, 0);
                @export var mode: Mode = Mode.idle;
                @export var target: Entity = null;
                @export var icon: Asset = "@res://Icons/player.png";
            }
            @resource(id: "game.settings") struct Settings { @export var level = 1; }
            """)
        let value = try #require(JSONSerialization.jsonObject(with: AdaScriptAgentSchemaCatalog.encoded(sources: [source])) as? [String: Any])
        let schemas = try #require(value["schemas"] as? [[String: Any]])
        let player = try #require(schemas.first { $0["typeName"] as? String == "game.player" })
        #expect(player["aliases"] as? [String] == ["OldPlayer"])
        #expect(player["source"] as? String == "Sources/Player.ada")
        let fields = try #require(player["fields"] as? [[String: Any]])
        #expect(fields.count == 9)
        #expect(fields.first { $0["name"] as? String == "mode" }?["cases"] as? [String] == ["idle", "walking"])
        let payload = try #require(player["defaultPayload"] as? [String: Any])
        #expect(payload["health"] as? Int == 100)
        #expect(payload["target"] as? Int == -1)
        #expect(schemas.first { $0["typeName"] as? String == "game.settings" }?["kind"] as? String == "resource")
    }

    @Test func duplicateStableIDsAreNotAdvertisedAsValidSchemas() {
        #expect(throws: AdaScriptSchemaError.self) {
            try AdaScriptAgentSchemaCatalog.encoded(sources: [.init(path: "Sources/Bad.ada", source: """
                @component(id: "game.same") struct First { @export var x = 0; }
                @component(id: "game.same") struct Second { @export var x = 0; }
                """)])
        }
    }
}
