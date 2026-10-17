@_spi(AdaEngine) import AdaEngine
import Foundation

/// Complete example projects whose AdaScript, UI and notes are real files under `Assets/Examples`.
///
/// The Swift side only adds what must be generated: the project configuration and the scene.
@MainActor
enum EditorAgentBundledExamples {
    static let sideScrollerID = "side-scroller-3d"

    /// Pure gameplay and tests of the side-scroller example, as project-relative paths (`Sources/...`, `Tests/...`).
    static func files(of example: String, bundle: Bundle = .editor) -> [String: String] {
        guard let root = bundle.url(forResource: example, withExtension: nil, subdirectory: "Assets/Examples") else { return [:] }
        let base = root.standardizedFileURL.path + "/"
        var result: [String: String] = [:]
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        while let url = enumerator?.nextObject() as? URL {
            guard ["ada", "ui", "md", "txt"].contains(url.pathExtension), let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            result[String(url.standardizedFileURL.path.dropFirst(base.count))] = text
        }
        return result
    }

    static func sideScroller3D(bundle: Bundle = .editor) -> EditorAgentKnowledge.Example {
        let description = """
            Complete multi-file 3D side-scroller (flappy / runner style) in AdaScript: Config, Rules, Components, one system per behaviour \
            (input, phase, restart, flight, obstacles, collision, score, audio), @query ECS queries, Space/click/R input actions, gravity and flap, \
            a reused obstacle pool, collisions, score, game over and restart, AudioSource cues, a .ui HUD, camera and light, @test tests and \
            asset generator sources. Read README.md first.
            """
        var project = ProjectSystem.defaultProject(projectName: "Side Runner 3D", buildSystem: .adaScript)
        project.runtime.moduleName = "SideRunner3D"
        project.runtime.entry = .init(scene: SceneDocumentFormat.defaultScenePath)
        project.runtime.plugins.preset = .game3D
        project.inputActions = [
            InputAction(name: "Flap", bindings: [.key(.space), .mouseButton(.left), .touch]),
            InputAction(name: "Restart", bindings: [.key(.r)]),
        ]
        var files = files(of: sideScrollerID, bundle: bundle)
        do {
            files[".ada/project.json"] = try EditorAgentToolEncoding.string(JSONEncoder().encode(project))
            files[SceneDocumentFormat.defaultScenePath] = try sideScrollerScene().encodedYAML()
        } catch {
            return .init(id: sideScrollerID, description: "Example could not be encoded: \(error.localizedDescription)", files: [:])
        }
        return .init(
            id: sideScrollerID,
            description: description,
            files: files,
            tags: ["3D game", "3D", "side scroller", "side-scroller", "flappy", "runner", "endless", "arcade", "multi-file", "ECS", "gameplay"]
        )
    }

    static func sideScrollerScene() -> EditorSceneModel {
        EditorComponentRegistry.registerBuiltIns()
        var scene = EditorSceneModel.default(projectName: "Side Runner 3D")
        let types = (
            transform: EditorBuiltInComponentType.transform, mesh: EditorBuiltInComponentType.mesh3D,
            visibility: EditorBuiltInComponentType.visibility, audio: EditorBuiltInComponentType.audioSource
        )
        func color(_ red: Double, _ green: Double, _ blue: Double) -> EditorSceneValue {
            .object(["red": .double(red), "green": .double(green), "blue": .double(blue), "alpha": .double(1)])
        }
        func transform(_ position: [Double], scale: [Double] = [1, 1, 1], rotation: [Double] = [0, 0, 0, 1]) -> EditorComponentPayload {
            [
                "position": .array(position.map(EditorSceneValue.double)),
                "rotation": .array(rotation.map(EditorSceneValue.double)),
                "scale": .array(scale.map(EditorSceneValue.double)),
            ]
        }
        func mesh(_ shape: String, _ size: Double, _ rgb: (Double, Double, Double)) -> EditorComponentPayload {
            var payload = EditorComponentRegistry.defaultPayload(for: types.mesh)
            payload["mesh"] = .string(shape)
            payload["size"] = .double(size)
            payload["color"] = color(rgb.0, rgb.1, rgb.2)
            payload["roughness"] = .double(0.75)
            return payload
        }
        func entity(_ id: String, _ name: String, parent: String? = nil, _ components: [String: EditorComponentPayload]) -> EditorSceneEntity {
            EditorSceneEntity(id: id, name: name, enabled: true, parent: parent, components: components)
        }
        func visual(_ shape: String, _ size: Double, _ rgb: (Double, Double, Double), at position: [Double], scale: [Double] = [1, 1, 1]) -> [String: EditorComponentPayload] {
            [
                types.transform: transform(position, scale: scale),
                types.visibility: EditorComponentRegistry.defaultPayload(for: types.visibility),
                types.mesh: mesh(shape, size, rgb),
            ]
        }

        var camera = EditorComponentRegistry.defaultPayload(for: EditorBuiltInComponentType.camera)
        camera["projection"] = .string("perspective")
        camera["backgroundColor"] = color(0.63, 0.84, 0.91)
        var sun = EditorComponentRegistry.defaultPayload(for: EditorBuiltInComponentType.directionalLight3D)
        sun["intensity"] = .double(2)
        var entities = [
            entity("camera", "Camera", [types.transform: transform([0, 0.3, 11]), EditorBuiltInComponentType.camera: camera]),
            entity("sun", "Sun", [types.transform: transform([0, 4, 4], rotation: [-0.342, 0, 0, 0.940]), EditorBuiltInComponentType.directionalLight3D: sun]),
            entity("ground", "Ground", visual("Cube", 1, (0.91, 0.79, 0.55), at: [0, -3.2, 0], scale: [40, 0.4, 4])),
        ]
        var player = visual("Sphere", 0.7, (1, 0.69, 0.08), at: [-3, 0, 0])
        player["runner.player"] = ["velocity": .double(0)]
        entities.append(entity("player", "Player", player))
        for slot in 0..<4 {
            let id = "obstacle-\(slot)"
            entities.append(entity(id, "Obstacle \(slot)", [
                types.transform: transform([4 + 5.5 * Double(slot), 0, 0]),
                "runner.obstacle": ["slot": .int(slot), "gapY": .double(0), "passed": .bool(false)],
            ]))
            // The columns are children, so moving the obstacle entity moves both; 1.3 is Config.gapHalfHeight.
            entities.append(entity("\(id)-top", "Top pipe", parent: id, visual("Cube", 1, (0.15, 0.67, 0.4), at: [0, 4.3, 0], scale: [1.2, 6, 1.2])))
            entities.append(entity("\(id)-bottom", "Bottom pipe", parent: id, visual("Cube", 1, (0.15, 0.67, 0.4), at: [0, -4.3, 0], scale: [1.2, 6, 1.2])))
        }
        for cue in ["flap", "score", "crash"] {
            var audio = EditorComponentRegistry.defaultPayload(for: types.audio)
            audio["source"] = .string("@res://Audio/\(cue).wav")
            entities.append(entity("sound-\(cue)", "Sound \(cue)", [
                types.transform: transform([0, 0.3, 11]), types.audio: audio, "runner.sound-cue": ["name": .string(cue)],
            ]))
        }
        var ui = EditorComponentRegistry.defaultPayload(for: EditorBuiltInComponentType.uiComponent)
        ui["path"] = .string("@res://UI/Hud.ui")
        ui["scriptBindings"] = .string(
            #"{"score":{"script":"runner.hud","field":"score"},"status":{"script":"runner.hud","field":"status"},"hint":{"script":"runner.hud","field":"hint"}}"#
        )
        // Shared round data lives on one entity, so a scene can author it and TestWorld can read it (it cannot read @resource).
        entities.append(entity("game", "Game", [
            types.transform: transform([0, 0, 0]),
            "runner.state": ["phase": .int(0), "score": .int(0), "best": .int(0), "nextSequence": .int(0), "resetRequested": .bool(true)],
            "runner.intent": ["flap": .bool(false), "restart": .bool(false)],
            "runner.cues": ["flap": .bool(false), "score": .bool(false), "crash": .bool(false)],
            EditorBuiltInComponentType.scriptableComponents: ["scripts": .array([.object(["type": .string("runner.hud"), "version": .int(1), "payload": .object([:])])])],
            EditorBuiltInComponentType.uiComponent: ui,
        ]))
        scene.entities = entities
        scene.editor = .init(selectedEntity: "player", expandedEntities: [])
        return scene
    }
}
