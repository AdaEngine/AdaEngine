import AdaEngine
import Foundation

@testable import AdaEditor

@MainActor
extension EditorVRWorkspace {
    func createStarter(at parent: URL) throws {
        guard !isImmersed, document?.isDirty != true else { throw EditorVRWorkspaceError.closeCurrentScene }
        let name = "VR Workspace \(Int(Date().timeIntervalSince1970))"
        let fixtureStore = EditorProjectStore(storageURL: parent.appendingPathComponent("starter-recents.json"), documentsDirectoryURL: parent)
        let reference = try fixtureStore.createProject(named: name, at: parent, template: .adaScript, asPackage: true)
        let root = URL(fileURLWithPath: reference.path, isDirectory: true)
        var model = EditorSceneModel.default(projectName: name)
        model.entities.removeAll()
        let floor = model.addEntity(template: .model3D, parentID: nil)
        let box = model.addEntity(template: .model3D, parentID: nil)
        let sphere = model.addEntity(template: .model3D, parentID: nil)
        let light = model.addEntity(template: .directionalLight3D, parentID: nil)
        let placements: [(String, Vector3, Vector3)] = [
            (floor.id, Vector3(0, -0.15, 2), Vector3(10, 0.1, 10)),
            (box.id, Vector3(-0.5, 1.2, 1.5), Vector3(0.4, 0.4, 0.4)),
            (sphere.id, Vector3(0.7, 1, 2), Vector3(0.6, 0.6, 0.6)),
            (light.id, Vector3.zero, Vector3.one),
        ]
        for (id, position, scale) in placements {
            if let index = model.entities.firstIndex(where: { $0.id == id }) {
                model.entities[index].parent = nil
                model.entities[index].components[EditorBuiltInComponentType.transform] = Self.fixtureTransformPayload(Transform(scale: scale, position: position))
                model.entities[index].name = id == floor.id ? "Floor" : id == box.id ? "Box" : id == sphere.id ? "Sphere" : "Sun"
            }
        }
        if let index = model.entities.firstIndex(where: { $0.id == sphere.id }) {
            model.entities[index].components[EditorBuiltInComponentType.mesh3D]?["mesh"] = .string("Sphere")
        }
        model.selectEntity(box.id)
        let sceneURL = root.appendingPathComponent(SceneDocumentFormat.defaultScenePath)
        try model.encodedYAML().write(to: sceneURL, atomically: true, encoding: .utf8)
        try openProject(at: root)
    }

    private static func fixtureTransformPayload(_ transform: Transform) -> EditorComponentPayload {
        [
            "position": .array([transform.position.x, transform.position.y, transform.position.z].map { .double(Double($0)) }),
            "rotation": .array([transform.rotation.x, transform.rotation.y, transform.rotation.z, transform.rotation.w].map { .double(Double($0)) }),
            "scale": .array([transform.scale.x, transform.scale.y, transform.scale.z].map { .double(Double($0)) }),
        ]
    }
}
