import AdaEngine
import Foundation
import MCP
import Testing

@testable import AdaEditor

@MainActor
@Suite("Agent voxel generation", .serialized)
struct EditorAgentVoxelToolTests {
    @Test("Generates a .vox file that the engine importer reads back")
    func generatesVoxFile() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = EditorMobileAgentToolService(projectURL: root)
        let result = await service.handle(
            name: "editor.voxel.generate",
            arguments: [
                "destination": "Assets/Models/tree.vox",
                "source": "func build(model) { model.size(4, 4, 4); model.palette(1, 10, 200, 30); model.box(0, 0, 0, 3, 3, 0, 1); }",
            ]
        )
        #expect(result.ok, "\(result.payload)")
        let payload = try #require(JSONSerialization.jsonObject(with: Data(result.payload.utf8)) as? [String: Any])
        #expect(payload["voxelCount"] as? Int == 16)
        #expect(payload["assetReference"] as? String == "@res://Models/tree.vox")

        let file = try VOXLoader().load(data: Data(contentsOf: root.appendingPathComponent("Assets/Models/tree.vox")))
        #expect(file.models.first?.voxels.count == 16)
        #expect(file.palette.color(forIndex: 1) == VOXColor(red: 10, green: 200, blue: 30))
    }

    @Test("Refuses overwrites, bad paths and failing scripts without writing files")
    func rejectsUnsafeRequests() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = EditorMobileAgentToolService(projectURL: root)
        let source = "func build(model) { model.size(2, 2, 2); model.voxel(0, 0, 0, 1); }"
        #expect((await service.handle(name: "editor.voxel.generate", arguments: ["destination": "Assets/a.vox", "source": .string(source)])).ok)
        for destination in ["Assets/a.vox", "Assets/a.txt", "../outside.vox", "/tmp/outside.vox", "Sources/a.vox"] {
            let result = await service.handle(name: "editor.voxel.generate", arguments: ["destination": .string(destination), "source": .string(source)])
            #expect(!result.ok, "\(destination)")
        }
        let failing = await service.handle(
            name: "editor.voxel.generate",
            arguments: ["destination": "Assets/b.vox", "source": "func build(model) { System.exit(1); }"]
        )
        #expect(!failing.ok)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("Assets/b.vox").path))
    }

    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AgentVoxelTools-\(UUID())")
        for path in ["Assets/Models", "Sources"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(path), withIntermediateDirectories: true)
        }
        try ProjectSystem.saveProject(ProjectSystem.defaultProject(projectName: "Voxel Tools", buildSystem: .adaScript), at: root)
        return root
    }
}
