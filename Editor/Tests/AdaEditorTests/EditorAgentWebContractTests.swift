@_spi(AdaEngine) import AdaEngine
import AdaStudioCore
import Foundation
import Testing

@testable import AdaEditor

@MainActor
@Suite("Browser agent contract export")
struct EditorAgentWebContractTests {
    @Test func exportsEverySupportedComponentAndCanonicalInput() throws {
        let data = try EditorAgentWebContract.encoded()
        let value = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let components = try #require(value["components"] as? [[String: Any]])
        #expect(Set(components.compactMap { $0["typeName"] as? String }) == StudioRuntimeCapabilities.components)
        let input = try #require(value["input"] as? [String: Any])
        let bindings = try #require(input["bindings"] as? [[String: Any]])
        #expect(bindings.count >= 146)
        for entry in bindings {
            let encoded = try JSONSerialization.data(withJSONObject: try #require(entry["encoded"]))
            let binding = try JSONDecoder().decode(InputBinding.self, from: encoded)
            try InputAction.validate([InputAction(name: "Probe", bindings: [binding])])
        }
        let space = try #require(bindings.first { $0["kind"] as? String == "key" && $0["name"] as? String == "space" })
        #expect(try JSONDecoder().decode(InputBinding.self, from: JSONSerialization.data(withJSONObject: try #require(space["encoded"]))) == .key(.space))
        let camera = try #require(components.first { $0["typeName"] as? String == "AdaRender.Camera" })
        let fields = try #require(camera["fields"] as? [[String: Any]])
        #expect(!fields.contains { $0["name"] as? String == "near" })
        #expect(fields.first { $0["name"] as? String == "renderOrder" }?["maximum"] as? Double == Double(Int32.max))
        let physics = try #require(components.first { $0["typeName"] as? String == "AdaPhysics.PhysicsBody2DComponent" })
        let physicsPayload = try #require(physics["defaultPayload"] as? [String: Any])
        let filter = try #require(physicsPayload["filter"] as? [String: Any])
        #expect(filter["collisionBitMask"] as? String == String(UInt64.max))
        let exactJSON = try #require(physics["defaultPayloadJSON"] as? String)
        let decoded = try JSONDecoder().decode(PhysicsBody2DComponent.self, from: Data(exactJSON.utf8))
        #expect(decoded.filter.collisionBitMask.rawValue == UInt64.max)
        let sprite = try #require(components.first { $0["typeName"] as? String == "AdaSprite.Sprite" })
        let spriteFields = try #require(sprite["fields"] as? [[String: Any]])
        let modes = try #require(spriteFields.first { $0["name"] as? String == "imageMode" }?["examples"] as? [String: Any])
        for mode in modes.values { _ = try JSONDecoder().decode(SpriteImageMode.self, from: JSONSerialization.data(withJSONObject: mode)) }
        let physicsFields = try #require(physics["fields"] as? [[String: Any]])
        let shapes = try #require(physicsFields.first { $0["name"] as? String == "shapes" }?["examples"] as? [String: Any])
        for shape in shapes.values { _ = try JSONDecoder().decode([Shape2DResource].self, from: JSONSerialization.data(withJSONObject: shape)) }
        for example in EditorAgentKnowledge.examples where ["basic-3d-scene", "side-scroller-3d"].contains(example.id) {
            let text = try #require(example.files[SceneDocumentFormat.defaultScenePath])
            let scene = try EditorSceneModel.decode(from: text)
            let camera = try #require(scene.entities.first { $0.components["AdaRender.Camera"] != nil })
            let payload = try #require(camera.components["AdaTransform.Transform"]?["position"])
            guard case let .array(position) = payload else { Issue.record("Missing camera position"); continue }
            #expect((position[2].doubleValue ?? 0) < 0, "Identity camera looks toward +Z; scene objects must be in front.")
        }
    }

    #if os(macOS)
    @Test func commandExportsAtomicallyWithoutAProject() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let output = root.appendingPathComponent("contract.json")
        let invocation = try EditorCLIInvocation(arguments: ["agent-resources", "--output", output.path])
        let report = await EditorCLI.execute(invocation)
        #expect(report.ok, Comment(rawValue: report.diagnostics.map(\.message).joined(separator: "\n")))
        #expect(report.artifacts == [output.path])
        #expect(try JSONSerialization.jsonObject(with: Data(contentsOf: output)) is [String: Any])
        #expect(throws: EditorCLIError.self) { try EditorCLIInvocation(arguments: ["agent-resources"]) }
    }
    #endif
}
