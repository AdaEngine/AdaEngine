import AdaApp
import AdaECS
import AdaRender
import AdaScene
import AdaUI
import Foundation
import Math

public struct ShadowRuntime: Resource {
    public var simulation: ShadowSimulation?
    public var error: String?
    var loadedPath: String?
    public init() {}
}

/// A separate channel lets physical keys coexist with script-bound virtual controls.
public struct ShadowKeyboardInput: Resource {
    public var value = ShadowPlayerInput()
    public var outerDrag: Vector2?
    public init() {}
}

@Component
public struct ShadowTransferItem: Codable, Sendable {
    public init() {}
}

public struct ShadowPlatformerPlugin: Plugin {
    public init() {}
    public func setup(in app: AppWorlds) {
        FoldPose.registerRuntimeType()
        ShadowPlayerInput.registerRuntimeType()
        ShadowProgress.registerRuntimeType()
        RuntimeTypeRegistry.registerComponent(ShadowLevel.self, names: ["ShadowLevel"])
        RuntimeTypeRegistry.registerComponent(FoldAttachment.self, names: ["FoldAttachment"])
        RuntimeTypeRegistry.registerComponent(ShadowTransferItem.self, names: ["ShadowTransferItem"])
        app.main.insertResource(ShadowRuntime())
        app.main.insertResource(ShadowPlayerInput())
        app.main.insertResource(ShadowKeyboardInput())
        app.main.insertResource(ShadowProgress())
        if app.main.getResource(FoldPose.self) == nil { app.main.insertResource(FoldPose()) }
        app.addSystem(ShadowPlatformerSystem.self)
    }
}

@PlainSystem(dependencies: [.after(ScriptComponentUpdateSystem.self)])
public struct ShadowPlatformerSystem {
    @Query<ShadowLevel> private var levels
    @FilterQuery<Ref<FoldAttachment>, With<ShadowTransferItem>> private var items
    @ResMut<ShadowRuntime> private var runtime
    @Res<ShadowPlayerInput> private var input
    @ResMut<ShadowKeyboardInput> private var keyboard
    @ResMut<FoldPose> private var pose
    @ResMut<ShadowProgress> private var progress
    @Res<DeltaTime> private var time
    @Res private var uiRuntime: UIComponentRuntimeResource?

    public init(world: World) {}

    @MainActor public func update(context: UpdateContext) {
        var levelPath: String?
        levels.forEach { if levelPath == nil { levelPath = $0.path } }
        guard let levelPath else { return }
        if runtime.loadedPath != levelPath {
            runtime.loadedPath = levelPath
            do {
                guard let uiRuntime else { throw ShadowLevelError.missingResources }
                let url = try uiRuntime.runtime.resources.resolve(levelPath)
                let definition = try JSONDecoder().decode(ShadowLevelDefinition.self, from: Data(contentsOf: url))
                var initialPlate: FoldAttachment?
                var itemCount = 0
                items.forEach { initialPlate = $0.wrappedValue; itemCount += 1 }
                guard itemCount == 1, let initialPlate else { throw ShadowLevelError.prismCount }
                runtime.simulation = ShadowSimulation(level: definition, pose: pose, plate: initialPlate)
                runtime.error = nil
            } catch { runtime.error = error.localizedDescription; runtime.simulation = nil }
        }
        guard var simulation = runtime.simulation else { return }
        if let point = keyboard.outerDrag { simulation.moveOuterItem(to: point); keyboard.outerDrag = nil }
        var controls = input
        if abs(keyboard.value.moveX) > 0.01 { controls.moveX = keyboard.value.moveX }
        controls.jump &+= keyboard.value.jump
        controls.flip &+= keyboard.value.flip
        controls.transfer &+= keyboard.value.transfer
        controls.restart &+= keyboard.value.restart
        simulation.advance(input: controls, angle: pose.angle, deltaTime: time.deltaTime)
        pose = simulation.pose
        progress.checkpoint = simulation.checkpoint
        progress.completed = simulation.completed
        progress.outer = simulation.pose.showsOuter
        progress.message = simulation.message
        items.forEach { $0.wrappedValue = simulation.plate }
        runtime.simulation = simulation
    }
}

private enum ShadowLevelError: LocalizedError {
    case missingResources, prismCount
    var errorDescription: String? {
        switch self {
        case .missingResources: "ShadowLevel requires a project resource root."
        case .prismCount: "ShadowLevel requires exactly one active Transfer Prism with a Fold Attachment."
        }
    }
}
