@testable import FoldGame
@_spi(AdaEngine) @testable import AdaEngine
@testable import AdaUI
import Foundation
import Math
import Testing

private typealias FoldPose = FoldGame.FoldPose
private typealias FoldSurface = FoldGame.FoldSurface
private typealias FoldAttachment = FoldGame.FoldAttachment
private typealias ShadowProjection = FoldGame.ShadowProjection
private typealias ShadowSimulation = FoldGame.ShadowSimulation
private typealias ShadowPlayerInput = FoldGame.ShadowPlayerInput
private typealias ShadowLevelDefinition = FoldGame.ShadowLevelDefinition
private typealias ShadowPlatformerPlugin = FoldGame.ShadowPlatformerPlugin
private typealias ShadowRuntime = FoldGame.ShadowRuntime
private typealias ShadowFoldSession = FoldGame.ShadowFoldSession
private typealias ShadowFoldHost = FoldGame.ShadowFoldHost

@MainActor @Suite(.serialized)
struct ShadowFoldTests {
    init() {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World(name: "Shadow Fold tests")))
        }

    }

    @Test func poseRoundTripAndShadowProjection() throws {
        for angle: Float in [45, 90, 135, 180] {
            let pose = FoldPose(angle: angle)
            let point = Vector3(123, 67, 24)
            for surface in FoldSurface.allCases {
                let roundTrip = pose.localPoint(pose.worldPoint(point, surface: surface), surface: surface)
                #expect(abs(roundTrip.x - point.x) < 0.001)
                #expect(abs(roundTrip.z - point.z) < 0.001)
            }
        }
        let definition = try level()
        let flat = ShadowProjection.polygons(bridge: definition.bridges[0], pose: FoldPose()).compactMap(\.top)
        let folded = ShadowProjection.polygons(bridge: definition.bridges[0], pose: FoldPose(angle: 135)).compactMap(\.top)
        #expect((flat.first?.b.x ?? 0) < 250)
        #expect((folded.first?.b.x ?? 0) > 285)
        #expect(FoldPose().project(light: Vector3(0, 0, 10), point: Vector3(1, 0, 10), onto: .innerLeft) == nil)
    }

    @Test func completeRealLevelWithFoldPortalAndCheckpoints() throws {
        var game = ShadowSimulation(level: try level())
        var input = ShadowPlayerInput()
        for _ in 0..<5 { game.advance(input: input, angle: 180, deltaTime: 1 / 60) }
        #expect(game.grounded)
        input.moveX = 1
        for _ in 0..<400 {
            if game.player.x > 260, game.grounded { input.jump += 1 }
            game.advance(input: input, angle: 135, deltaTime: 1 / 60)
            if game.checkpoint == 1 { break }
        }
        try #require(game.checkpoint == 1, "First section stopped at \(game.player)")
        for _ in 0..<400 {
            if (game.player.x > 318 && game.player.x < 345 || (game.player.x > 433 && game.player.x < 450)), game.grounded { input.jump += 1 }
            game.advance(input: input, angle: 90, deltaTime: 1 / 60)
            if game.checkpoint == 2 { break }
        }
        try #require(game.checkpoint == 2, "Seam stopped at \(game.player)")
        #expect(game.playerSurface == .innerRight)
        input.moveX = 0; input.flip += 1
        game.advance(input: input, angle: 90, deltaTime: 1 / 60)
        #expect(game.pose.showsOuter)
        let pausedPosition = game.player
        input.moveX = 1
        for _ in 0..<20 { game.advance(input: input, angle: 90, deltaTime: 1 / 60) }
        #expect(game.player == pausedPosition)
        input.transfer += 1
        game.advance(input: input, angle: 90, deltaTime: 1 / 60)
        #expect(!game.transferred)
        game.moveOuterItem(to: game.level.portal)
        input.transfer += 1
        game.advance(input: input, angle: 90, deltaTime: 1 / 60)
        #expect(game.transferred)
        #expect(game.plate.surface == .innerRight)
        input.flip += 1
        game.advance(input: input, angle: 80, deltaTime: 1 / 60)
        for _ in 0..<400 {
            if game.player.x > 510 && game.player.x < 550, game.grounded { input.jump += 1 }
            game.advance(input: input, angle: 80, deltaTime: 1 / 60)
            if game.completed { break }
        }
        #expect(game.completed == true, "Last section stopped at \(game.player)")
    }

    @Test func movingShadowCarriesAndDisappearanceRestoresCheckpoint() throws {
        var definition = try level()
        definition.start = Vector2(220, 120)
        var game = ShadowSimulation(level: definition)
        let input = ShadowPlayerInput()
        for _ in 0..<60 { game.advance(input: input, angle: 135, deltaTime: 1 / 60) }
        try #require(game.grounded)
        let previous = game.player
        game.advance(input: input, angle: 145, deltaTime: 1 / 60)
        #expect(abs(game.player.x - previous.x) > 1)
        var restored = false
        for _ in 0..<120 {
            game.advance(input: input, angle: 70, deltaTime: 1 / 60)
            if game.player == definition.start { restored = true; break }
        }
        #expect(restored)
    }

    @Test func occupiedPortalDoesNotMoveOrDuplicatePrism() throws {
        var definition = try level()
        definition.start = Vector2(500, 100)
        definition.transferDestination = Vector3(100, 100, 0)
        var game = ShadowSimulation(level: definition)
        var input = ShadowPlayerInput()
        game.advance(input: input, angle: 180, deltaTime: 1 / 60)
        input.flip += 1
        game.advance(input: input, angle: 180, deltaTime: 1 / 60)
        try #require(game.pose.showsOuter)
        game.moveOuterItem(to: definition.portal)
        let position = game.plate.position
        input.transfer += 1
        game.advance(input: input, angle: 180, deltaTime: 1 / 60)
        #expect(game.transferred == false)
        #expect(game.plate.surface == .outer)
        #expect(game.plate.position == position)
        #expect(game.message.contains("occupied"))
    }

    @Test func focusLossReleasesKeyboardMovement() {
        let session = ShadowFoldSession()
        let host = ShadowFoldHost()
        host.session = session
        host.onKeyEvent(KeyEvent(window: RID(), keyCode: .d, modifiers: [], status: .down, time: 0, isRepeated: false))
        #expect(session.heldKeys.contains(.d))
        host.onFocusChanged(isFocused: false)
        #expect(session.heldKeys.isEmpty)
        #expect(session.keyboard.value.moveX == 0)
    }

    @Test func projectLoadsRealScriptsAndControls() async throws {
        let world = World(name: "Fold integration")
        let app = AppWorlds(main: world)
        InputPlugin().setup(in: app)
        ScriptableObjectPlugin().setup(in: app)
        ShadowPlatformerPlugin().setup(in: app)
        FoldProject.installScripts(in: app)
        try FoldProject.load(into: world, resources: root.appendingPathComponent("Assets"))
        await world.runScheduler(.update)
        let panel = try #require(world.getEntities().compactMap { $0.components[CompanionPanel.self] }.first)
        let view = try #require(try panel.ui.resolveView(runtime: world.getResource(UIComponentRuntimeResource.self)?.runtime) as? UIContainerView<AnyView>)
        view.frame = Rect(x: 0, y: 0, width: 900, height: 650)
        view.layoutSubviews()
        _ = try view.uiTapNode(matching: .accessibilityIdentifier("ShadowFold.jump"))
        await world.runScheduler(.update)
        await world.runScheduler(.update)
        #expect(world.getResource(ShadowPlayerInput.self)?.jump == 1)
        #expect(world.getResource(ShadowRuntime.self)?.simulation != nil)
        #expect(world.getResource(ShadowRuntime.self)?.error == nil)
    }

    @Test func repeatedPlaySessionsKeepWorking() async throws {
        for _ in 0..<3 { try await projectLoadsRealScriptsAndControls() }
    }

    @Test func authoredPoseAndPrismPlacementSurviveReset() throws {
        let definition = try level()
        let authored = FoldAttachment(surface: .outer, position: Vector3(180, 240, 60))
        var game = ShadowSimulation(level: definition, pose: FoldPose(angle: 135), plate: authored)
        var input = ShadowPlayerInput()
        game.advance(input: input, angle: 90, deltaTime: 1 / 60)
        input.restart += 1
        game.advance(input: input, angle: 90, deltaTime: 1 / 60)
        #expect(game.pose.playableAngle == 135)
        #expect(game.plate.position == authored.position)
    }

    private func level() throws -> ShadowLevelDefinition {
        try JSONDecoder().decode(ShadowLevelDefinition.self, from: Data(contentsOf: root.appendingPathComponent("Assets/Levels/intro.json")))
    }
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
}
