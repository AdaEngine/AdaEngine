@testable import AdaApp
import AdaECS
import AdaScene
import AdaScripting
import AdaTransform
import Foundation
import Math
import Testing

@MainActor
@Suite("AdaScript Camera2D", .serialized)
struct AdaScriptCamera2DTests {
    @Test("A script builds a follow camera and a target, then shakes, zooms and re-aims it through fields")
    func constructAndControl() async throws {
        RuntimeTypeRegistry.registerComponent(Camera2DController.self, names: ["Camera2DController"])
        RuntimeTypeRegistry.registerComponent(CameraTarget2D.self, names: ["CameraTarget2D"])
        RuntimeTypeRegistry.registerComponent(Transform.self, names: ["Transform"], makeDefault: { Transform() })

        let spawn = try AdaScriptPlugin(source: """
            @system class SpawnCamera {
                func update(context) {
                    context.world.spawn([Transform(), Camera2DController(targetGroup: "hero", smoothingTime: 0.2, zoom: 2)]);
                    context.world.spawn([Transform(), CameraTarget2D(group: "hero", weight: 2)]);
                }
            }
            """)
        let spawnWorld = World()
        spawn.setup(in: AppWorlds(main: spawnWorld))
        await spawnWorld.runScheduler(.update)
        #expect(spawn.diagnostics.isEmpty, Comment(rawValue: spawn.diagnostics.joined(separator: "\n")))
        let built = try #require(spawnWorld.getEntities().compactMap { $0.components[Camera2DController.self] }.first)
        #expect(built.targetGroup == "hero" && built.smoothingTime == 0.2 && built.zoom == 2)
        let target = try #require(spawnWorld.getEntities().compactMap { $0.components[CameraTarget2D.self] }.first)
        #expect(target.group == "hero" && target.weight == 2)

        let controls = try AdaScriptPlugin(source: """
            @system class ControlCamera {
                @query(Camera2DController) var cameras;
                func update(context) {
                    for (var entity in cameras) {
                        entity.camera2DController.trauma = 0.75;
                        entity.camera2DController.zoom = 3;
                        entity.camera2DController.limitsEnabled = true;
                        entity.camera2DController.limitMax = Vector2(640, 480);
                        entity.camera2DController.snapCount = 1;
                        entity.camera2DController.targetGroup = "boss";
                    }
                }
            }
            """)
        let controlWorld = World()
        let entity = controlWorld.spawn { built }
        controls.setup(in: AppWorlds(main: controlWorld))
        await controlWorld.runScheduler(.update)
        #expect(controls.diagnostics.isEmpty, Comment(rawValue: controls.diagnostics.joined(separator: "\n")))
        let controlled = try #require(entity.components[Camera2DController.self])
        #expect(controlled.trauma == 0.75)
        #expect(controlled.zoom == 3)
        #expect(controlled.limitsEnabled)
        #expect(controlled.limitMax == Vector2(640, 480))
        #expect(controlled.snapCount == 1)
        #expect(controlled.targetGroup == "boss")
    }
}
