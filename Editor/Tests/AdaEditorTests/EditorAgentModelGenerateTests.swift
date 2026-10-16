import AdaEngine
import Foundation
import MCP
import Testing

@testable import AdaEditor

@MainActor
@Suite("Agent procedural model generation", .serialized)
struct EditorAgentModelGenerateTests {
    private static let lamp = """
        func build(model) {
            model.material(1, 0.55, 0.55, 0.6);
            model.surface(1, 0.8, 0.35);
            var lamp = model.group();
            model.name(lamp, "Desk lamp");
            var base = model.cylinder(0.12, 0.15, 0.04, 24);
            model.paint(base, 1);
            model.place(base, 0.0, 0.02, 0.0);
            model.parent(base, lamp);
            var bulb = model.sphere(0.045, 12);
            model.place(bulb, 0.0, 0.52, 0.0);
            model.parent(bulb, lamp);
        }
        """

    @Test("Generates a GLB under Assets that the glTF inspector reads back")
    func generatesGLB() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = EditorMobileAgentToolService(projectURL: root)
        let result = await service.handle(name: "editor.model.generate", arguments: ["destination": "Assets/Models/lamp.glb", "source": .string(Self.lamp)])
        #expect(result.ok, "\(result.payload)")
        let payload = try #require(JSONSerialization.jsonObject(with: Data(result.payload.utf8)) as? [String: Any])
        #expect(payload["assetReference"] as? String == "@res://Models/lamp.glb")
        #expect((payload["materials"] as? [String])?.count == 2)
        #expect((payload["parts"] as? [[String: Any]])?.map { $0["name"] as? String } == ["Desk lamp", "Cylinder 1", "Sphere 2"])
        #expect((payload["triangleCount"] as? Int ?? 0) > 100)

        let inspected = await service.handle(name: "editor.model.inspect", arguments: ["path": "Assets/Models/lamp.glb"])
        #expect(inspected.ok, "\(inspected.payload)")
    }

    @Test("Refuses overwrites, bad paths and failing scripts without writing files")
    func rejectsUnsafeRequests() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = EditorMobileAgentToolService(projectURL: root)
        let source = Value.string(Self.lamp)
        #expect((await service.handle(name: "editor.model.generate", arguments: ["destination": "Assets/a.glb", "source": source])).ok)
        for destination in ["Assets/a.glb", "Assets/a.vox", "Assets/a.gltf", "../outside.glb", "/tmp/outside.glb", "Sources/a.glb"] {
            let result = await service.handle(name: "editor.model.generate", arguments: ["destination": .string(destination), "source": source])
            #expect(!result.ok, "\(destination)")
        }
        let failing = await service.handle(
            name: "editor.model.generate",
            arguments: ["destination": "Assets/b.glb", "source": "func build(model) { model.box(0.0, 1.0, 1.0); }"]
        )
        #expect(!failing.ok)
        #expect(failing.payload.contains("model.box"))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("Assets/b.glb").path))
    }

    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AgentModelGenerate-\(UUID())")
        for path in ["Assets/Models", "Sources"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(path), withIntermediateDirectories: true)
        }
        try ProjectSystem.saveProject(ProjectSystem.defaultProject(projectName: "Model Generate", buildSystem: .adaScript), at: root)
        return root
    }
}
