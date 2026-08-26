import Testing
@_spi(Internal) import AdaRender
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

    @Test
    func pendingRenderTarget_isNotSubmittedAgain() async throws {
        unsafe RenderEngine.configurations.preferredBackend = .headless

        let coordinator = SceneViewCoordinator(
            make: { _ in },
            updateContent: { _, _ in }
        )

        coordinator.bootstrapIfNeeded()
        for _ in 0..<500 {
            if coordinator.appWorlds != nil {
                break
            }
            await Task.yield()
        }

        let appWorlds = try #require(coordinator.appWorlds)
        coordinator.updateSize(SizeInt(width: 16, height: 16), scaleFactor: 1)

        let poolSize = max(3, unsafe RenderEngine.configurations.maxFramesInFlight + 2)
        var submittedTargets = Set<ObjectIdentifier>()
        for _ in 0..<poolSize {
            coordinator.tick(0.016)
            let camera = try #require(sceneViewCamera(in: appWorlds.main))
            guard case let .texture(handle) = camera.renderTarget else {
                Issue.record("SceneView camera must render into a texture.")
                break
            }
            submittedTargets.insert(ObjectIdentifier(handle.asset))
            #expect(camera.isActive)
        }

        #expect(submittedTargets.count == poolSize)

        coordinator.tick(0.016)
        let exhaustedCamera = try #require(sceneViewCamera(in: appWorlds.main))
        #expect(!exhaustedCamera.isActive)
        coordinator.shutdown()
    }

    @Test
    func completedRenderTargets_keepStableDisplayTextureIdentity() async throws {
        unsafe RenderEngine.configurations.preferredBackend = .headless

        let coordinator = SceneViewCoordinator(
            make: { _ in },
            updateContent: { _, _ in }
        )
        var displayTextureChangeCount = 0
        coordinator.renderTextureDidChange = {
            displayTextureChangeCount += 1
        }

        coordinator.bootstrapIfNeeded()
        for _ in 0..<500 {
            if coordinator.appWorlds != nil {
                break
            }
            await Task.yield()
        }

        let appWorlds = try #require(coordinator.appWorlds)
        coordinator.updateSize(SizeInt(width: 16, height: 16), scaleFactor: 1)
        displayTextureChangeCount = 0

        coordinator.tick(0.016)
        let firstCamera = try #require(sceneViewCamera(in: appWorlds.main))
        guard case let .texture(firstHandle) = firstCamera.renderTarget else {
            Issue.record("SceneView camera must render into a RenderTexture.")
            return
        }
        let firstTarget = try #require(firstHandle.asset)
        firstTarget.notifyRenderCompleted()
        for _ in 0..<50 where coordinator.renderTexture == nil {
            await Task.yield()
        }

        let stableDisplayTexture = try #require(coordinator.renderTexture)
        let displayIdentity = ObjectIdentifier(stableDisplayTexture)
        let firstBackingIdentity = ObjectIdentifier(stableDisplayTexture.gpuTexture)
        #expect(displayTextureChangeCount == 1)

        coordinator.tick(0.016)
        let secondCamera = try #require(sceneViewCamera(in: appWorlds.main))
        guard case let .texture(secondHandle) = secondCamera.renderTarget else {
            Issue.record("SceneView camera must rotate to another RenderTexture.")
            return
        }
        let secondTarget = try #require(secondHandle.asset)
        #expect(secondTarget !== firstTarget)
        secondTarget.notifyRenderCompleted()
        for _ in 0..<50 where ObjectIdentifier(stableDisplayTexture.gpuTexture) == firstBackingIdentity {
            await Task.yield()
        }

        #expect(ObjectIdentifier(try #require(coordinator.renderTexture)) == displayIdentity)
        #expect(ObjectIdentifier(stableDisplayTexture.gpuTexture) != firstBackingIdentity)
        #expect(displayTextureChangeCount == 1)
        coordinator.shutdown()
    }

    @Test
    func oversizedViewportSize_isIgnoredUntilValidSizeArrives() async throws {
        unsafe RenderEngine.configurations.preferredBackend = .headless

        let coordinator = SceneViewCoordinator(
            make: { _ in },
            updateContent: { _, _ in }
        )

        coordinator.updateSize(SizeInt(width: 475_659, height: 512), scaleFactor: 2)
        coordinator.bootstrapIfNeeded()
        for _ in 0..<500 {
            if coordinator.appWorlds != nil {
                break
            }
            await Task.yield()
        }

        let appWorlds = try #require(coordinator.appWorlds)
        #expect(sceneViewCamera(in: appWorlds.main) == nil)

        coordinator.updateSize(SizeInt(width: 800, height: 600), scaleFactor: 2)
        #expect(sceneViewCamera(in: appWorlds.main) != nil)
        coordinator.shutdown()
    }

    private func sceneViewCamera(in world: World) -> Camera? {
        for entity in world.getEntities() {
            if let camera: Camera = entity.components[Camera.self] {
                return camera
            }
        }
        return nil
    }
}
