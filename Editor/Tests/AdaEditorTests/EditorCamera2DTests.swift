@testable import AdaEditor
@_spi(AdaEngine) import AdaEngine
import Foundation
import Testing

@MainActor
@Suite("Camera 2D editor", .serialized)
struct EditorCamera2DTests {
    @Test("Both components are offered, with a default that matches the runtime defaults")
    func descriptors() throws {
        let controller = try #require(EditorComponentRegistry.descriptor(named: EditorBuiltInComponentType.camera2DController))
        let target = try #require(EditorComponentRegistry.descriptor(named: EditorBuiltInComponentType.cameraTarget2D))
        #expect(EditorComponentRegistry.addableDescriptors(for: nil).contains { $0.typeName == controller.typeName })
        #expect(EditorComponentRegistry.addableDescriptors(for: nil).contains { $0.typeName == target.typeName })

        // Every field of the descriptor is present in the default payload, and the other way round.
        #expect(Set(controller.fields.map(\.key)) == Set(controller.makeDefaultPayload().keys))
        #expect(Set(target.fields.map(\.key)) == Set(target.makeDefaultPayload().keys))

        let decoded = try #require(controller.decode(controller.makeDefaultPayload()) as? Camera2DController)
        let defaults = Camera2DController()
        #expect(decoded.zoom == defaults.zoom && decoded.maxZoom == defaults.maxZoom && decoded.minZoom == defaults.minZoom)
        #expect(decoded.traumaDecay == defaults.traumaDecay && decoded.shakeMaxOffset == defaults.shakeMaxOffset)
        #expect(decoded.shakeFrequency == defaults.shakeFrequency && decoded.isEnabled == defaults.isEnabled)
        let decodedTarget = try #require(target.decode(target.makeDefaultPayload()) as? CameraTarget2D)
        #expect(decodedTarget.group.isEmpty && decodedTarget.weight == 1)
    }

    @Test("Edited settings save, reopen, load in a world and drive the camera with the real systems")
    func sceneRoundTrip() async throws {
        var scene = EditorSceneModel.default(projectName: "Camera")
        let hero = scene.addEntity(preset: .empty)
        scene.addComponent(typeName: EditorBuiltInComponentType.transform, to: hero.id)
        scene.addComponent(typeName: EditorBuiltInComponentType.cameraTarget2D, to: hero.id)
        let camera = scene.addEntity(preset: .empty)
        scene.addComponent(typeName: EditorBuiltInComponentType.camera, to: camera.id)
        scene.addComponent(typeName: EditorBuiltInComponentType.camera2DController, to: camera.id)

        let type = EditorBuiltInComponentType.camera2DController
        let descriptor = try #require(EditorComponentRegistry.descriptor(named: type))
        let targetDescriptor = try #require(EditorComponentRegistry.descriptor(named: EditorBuiltInComponentType.cameraTarget2D))
        for (key, value) in [
            ("targetGroup", "hero"), ("zoom", "3"), ("smoothingTime", "0.25"), ("offset", "4, -2"), ("deadZone", "30, 12"),
            ("limitsEnabled", "true"), ("limitMin", "0, 0"), ("limitMax", "640, 480"), ("snapsToPixels", "true"), ("shakeMaxRoll", "2.5"),
        ] {
            let field = try #require(descriptor.fields.first { $0.key == key }, "missing field \(key)")
            scene.updateField(typeName: type, field: field, value: value, in: camera.id)
        }
        let group = try #require(targetDescriptor.fields.first { $0.key == "group" })
        scene.updateField(typeName: EditorBuiltInComponentType.cameraTarget2D, field: group, value: "hero", in: hero.id)

        let reopened = try EditorSceneModel.decode(from: scene.encodedYAML())
        let world = World()
        let result = EditorSceneFileLoader.load(model: reopened, into: world, loadsScriptableObjects: false, resourceRootURL: nil)
        #expect(result.warnings.isEmpty, Comment(rawValue: result.warnings.joined(separator: "\n")))
        let cameraID = try #require(result.entitiesByEditorID[camera.id])
        let heroID = try #require(result.entitiesByEditorID[hero.id])
        let loaded = try #require(world.get(Camera2DController.self, from: cameraID))
        #expect(loaded.targetGroup == "hero" && loaded.zoom == 3 && loaded.smoothingTime == 0.25)
        #expect(loaded.offset == Vector2(4, -2) && loaded.deadZone == Vector2(30, 12))
        #expect(loaded.limitsEnabled && loaded.limitMax == Vector2(640, 480) && loaded.snapsToPixels && loaded.shakeMaxRoll == 2.5)
        #expect(world.get(CameraTarget2D.self, from: heroID)?.group == "hero")

        // The loaded entities run under the real systems: the camera follows the hero in the frame the hero moves.
        world.addSystem(TransformSystem.self, on: .postUpdate)
        world.addSystem(ChildTransformSystem.self, on: .postUpdate)
        world.addSystem(Camera2DControllerSystem.self, on: .postUpdate)
        await world.runScheduler(.postUpdate, deltaTime: 1.0 / 60)
        world.getEntityByID(heroID)?.components[Transform.self]?.position = [300, 200, 0]
        for _ in 0..<2 { await world.runScheduler(.postUpdate, deltaTime: 1.0 / 60) }
        let position = try #require(world.get(Transform.self, from: cameraID)?.position)
        // First update snaps onto hero + offset; smoothing then eases toward the new place, so only direction and bounds are exact.
        #expect(position.x > 0 && position.x <= 304.5 && position.y > 0 && position.y <= 198)
    }

    @Test("Scene files from before the camera controller still load")
    func legacyScenesUnaffected() throws {
        var scene = EditorSceneModel.default(projectName: "Legacy")
        let entity = scene.addEntity(preset: .empty)
        scene.addComponent(typeName: EditorBuiltInComponentType.camera, to: entity.id)
        let world = World()
        let result = EditorSceneFileLoader.load(model: try EditorSceneModel.decode(from: scene.encodedYAML()), into: world, loadsScriptableObjects: false, resourceRootURL: nil)
        #expect(result.warnings.isEmpty)
        let id = try #require(result.entitiesByEditorID[entity.id])
        #expect(world.get(Camera2DController.self, from: id) == nil)
    }
}
