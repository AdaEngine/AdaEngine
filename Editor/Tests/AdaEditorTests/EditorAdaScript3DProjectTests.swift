@_spi(Internal) @testable import AdaApp
@_spi(AdaEngine) import AdaEngine
@_spi(Internal) import AdaInput
@_spi(Internal) import AdaRender
import Foundation
import Math
import Testing

@testable import AdaEditor

/// Opt-in integration against a real external AdaScript project, without copying game code into the engine.
@MainActor
@Suite(.serialized)
struct EditorAdaScript3DProjectTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ADA_SCRIPT_3D_PROJECT"] != nil))
    func loadsModelsAndRunsPortableControls() async throws {
        let directory = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["ADA_SCRIPT_3D_PROJECT"]))
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World(name: "AdaScript3DProjectTests")))
        }
        GLTFLoaderResolver.shared.setLoader(NativeGLTFLoader())
        EditorComponentRegistry.registerBuiltIns()
        let project = try ProjectSystem.loadProject(at: directory)
        let artifact = try EditorAdaScriptProjectBuilder().prepare(project: project, at: directory)
        #expect(artifact.report.viewCount == 0)
        #expect(artifact.report.sourceCount > 0)
        let app = AppWorlds(main: World())
        app.addPlugin(MainSchedulerPlugin()).addPlugin(TransformPlugin())
            .addPlugin(InputPlugin(actions: project.inputActions))
            .addPlugin(AssetsPlugin(assetDirectory: artifact.assetsDirectory))
            .addPlugin(Core3DPlugin()).addPlugin(Physics3DPlugin()).addPlugin(Model3DPlugin())
        let script = try AdaScriptPlugin(sources: artifact.sources, name: artifact.moduleName)
        app.addPlugin(script)
        try await app.build()
        let scene = try #require(artifact.sceneModel)
        let loaded = app.withExecutionContext {
            EditorSceneFileLoader.load(model: scene, into: app.main, resourceRootURL: artifact.assetsDirectory)
        }
        #expect(loaded.warnings.isEmpty, Comment(rawValue: loaded.warnings.joined(separator: "\n")))
        let character = try #require(app.main.getEntities().first { $0.components[CharacterController3DComponent.self] != nil })
        let camera = try #require(app.main.getEntities().first { $0.components[CameraCollision3DComponent.self] != nil })
        let reference = try #require(app.main.getEntities().first {
            $0.id != character.id && $0.components[ModelAnimationPlayback3DComponent.self] != nil
        })
        let initial = try #require(character.components[Transform.self]).position
        func step(_ count: Int) async {
            for _ in 0..<count {
                await app.main.runScheduler(.preUpdate, deltaTime: 1 / 60)
                await app.main.runScheduler(.update, deltaTime: 1 / 60)
                await app.main.runScheduler(.physicsSync)
                app.main.insertResource(FixedTime(deltaTime: 1 / 60))
                await app.main.runScheduler(.physicsStep)
                await app.main.runScheduler(.physicsWriteback)
                await app.main.runScheduler(.fixedPostUpdate, deltaTime: 1 / 60)
                await app.main.runScheduler(.postUpdate, deltaTime: 1 / 60)
            }
        }
        func key(_ code: KeyCode, _ status: KeyEvent.Status) {
            app.main.getRefResource(Input.self).wrappedValue.receiveEvent(KeyEvent(
                window: .empty, keyCode: code, modifiers: [], status: status, time: 0, isRepeated: false))
        }
        await step(20)
        #expect(character.components[CharacterController3DComponent.self]?.isGrounded == true)
        key(.w, .down)
        await step(35)
        key(.w, .up)
        #expect((try #require(character.components[Transform.self]).position - initial).length > 0.5)
        #expect(character.components[ModelAnimationPlayback3DComponent.self]?.clip == "Walk")
        key(.w, .down)
        key(.shift, .down)
        await step(20)
        #expect(character.components[ModelAnimationPlayback3DComponent.self]?.clip == "Run")
        key(.w, .up)
        key(.shift, .up)
        await step(40)
        #expect(character.components[ModelAnimationPlayback3DComponent.self]?.clip == "Idle")
        key(.space, .down)
        await step(3)
        key(.space, .up)
        #expect(character.components[ModelAnimationPlayback3DComponent.self]?.clip == "Jump")
        var peak: Float = 0
        var sawFall = false
        var sawLand = false
        for _ in 0..<90 {
            await step(1)
            peak = max(peak, try #require(character.components[Transform.self]).position.y)
            sawFall = sawFall || character.components[ModelAnimationPlayback3DComponent.self]?.clip == "Fall"
            sawLand = sawLand || character.components[ModelAnimationPlayback3DComponent.self]?.clip == "Land"
        }
        #expect(peak > 0.7 && sawFall && sawLand)
        #expect(character.components[CharacterController3DComponent.self]?.isGrounded == true)
        key(.r, .down)
        await step(1)
        key(.r, .up)
        await step(20)
        #expect((try #require(character.components[Transform.self]).position - initial).length < 0.03)
        #expect(camera.components[CameraCollision3DComponent.self]?.actualDistance ?? 0 > 0)
        let firstRoot = try #require(character.components[Model3DSourceState.self]?.rootEntityID)
        let secondRoot = try #require(reference.components[Model3DSourceState.self]?.rootEntityID)
        let firstAnimation = try #require(app.main.get(ModelAnimation3DComponent.self, from: firstRoot))
        let secondAnimation = try #require(app.main.get(ModelAnimation3DComponent.self, from: secondRoot))
        #expect(firstAnimation.player.instanceID != secondAnimation.player.instanceID)
        #expect(secondAnimation.player.speed == 0.65)
        #expect(firstAnimation.evaluationLOD == nil)
        #expect(secondAnimation.evaluationLOD != nil)
        #expect(camera.components[Environment3D.self]?.shadows.cascadeCount == 3)
        key(.num1, .down)
        await step(1)
        key(.num1, .up)
        await step(1)
        #expect(camera.components[Environment3D.self]?.shadows.isEnabled == false)
        key(.num8, .down)
        await step(1)
        key(.num8, .up)
        await step(1)
        let localLights = app.main.getEntities().compactMap { $0.components[PointLightComponent.self] }
        #expect(!localLights.isEmpty && localLights.allSatisfy { $0.intensity == 0 })
        #expect(script.diagnostics.isEmpty, Comment(rawValue: script.diagnostics.joined(separator: "\n")))
    }
}
