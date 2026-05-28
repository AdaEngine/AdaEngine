import Testing
@testable import AdaEngine

@MainActor
struct SceneViewTests {

    @Test
    func initializersCompile() {
        let sceneView = SceneView(
            make: { _ in },
            updateContent: { _, _ in }
        )
        _ = sceneView

        let sceneViewWithPlaceholder = SceneView(
            make: { _ in },
            updateContent: { _, _ in },
            placeholder: {
                Text("Loading")
            }
        )
        _ = sceneViewWithPlaceholder
    }

    @Test
    func makeRunsOnceBeforeUpdateContent() async throws {
        unsafe RenderEngine.configurations.preferredBackend = .headless

        var makeCallCount = 0
        var makeSawScheduler: SchedulerName?
        var madeWorld: World?
        var updateCallCount = 0
        var updateReceivedMadeWorld = false

        let coordinator = SceneViewCoordinator(
            make: { app in
                makeCallCount += 1
                makeSawScheduler = app.updateScheduler
                madeWorld = app.main
                app.addPlugin(RenderWorldPlugin())
            },
            updateContent: { world, _ in
                updateCallCount += 1
                updateReceivedMadeWorld = world === madeWorld
            }
        )

        coordinator.bootstrapIfNeeded()

        for _ in 0..<500 {
            if coordinator.appWorlds != nil {
                break
            }
            await Task.yield()
        }

        _ = try #require(coordinator.appWorlds)
        coordinator.updateSize(SizeInt(width: 16, height: 16), scaleFactor: 1)
        coordinator.tick(0.016)
        coordinator.shutdown()

        #expect(makeCallCount == 1)
        #expect(makeSawScheduler == nil)
        #expect(updateCallCount == 1)
        #expect(updateReceivedMadeWorld)
    }
}
