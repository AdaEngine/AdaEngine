//
//  WorldPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/11/22.
//

import AdaApp
import AdaECS
import AdaUtils

/// The plugin that sets up the render world.
public struct RenderWorldPlugin: Plugin {

    public init() {}

    /// Setup the render world.
    /// - Parameter app: The app to setup the render world for.
    public func setup(in app: AppWorlds) {
        VisibleEntities.registerComponent()
        Visibility.registerComponent()
        NoFrustumCulling.registerComponent()
        BoundingComponent.registerComponent()
        Texture.registerTypes()
        
        let renderWorld = AppWorlds(main: World(name: "RenderWorld"))
        renderWorld.updateScheduler = .render
        renderWorld.insertResource(RenderGraph(label: "RenderWorld_Root"))
        renderWorld.setExctractor(RenderWorldExctractor())
        renderWorld.main.setSchedulers([
            .extract,
            .update,
            .render
        ])

        renderWorld
            .insertResource(RenderDeviceHandler(renderDevice: RenderEngine.shared.renderDevice))
            .addSystem(RenderWorldRunnerSystem.self, on: .render)

        app.addSubworld(renderWorld, by: .renderWorld)
    }
}

public struct RenderDeviceHandler: Resource {
    public var renderDevice: RenderDevice

    public init(renderDevice: RenderDevice) {
        self.renderDevice = renderDevice
    }
}

/// The system that renders the world.
@System
@inline(__always)
func RenderWorldRunner(
    _ context: inout WorldUpdateContext,
    _ renderGraph: ResQuery<RenderGraph?>,
    _ renderDevice: ResQuery<RenderDeviceHandler?>
) async {
    let world = context.world
    await world.runScheduler(.update)

    let renderGraph = renderGraph.wrappedValue
    renderGraph?.update(from: world)
    Task.detached(priority: .high) {
        do {
            guard
                let renderGraph,
                let renderDevice = renderDevice.wrappedValue?.renderDevice
            else {
                return
            }
            let renderGraphExecutor = RenderGraphExecutor()
            try await renderGraphExecutor.execute(renderGraph, renderDevice: renderDevice, in: world)
        } catch {
            assertionFailure("Failed to execute render graph \(error)")
        }
    }
}

/// The extractor that extracts the main world to the render world.
struct RenderWorldExctractor: WorldExctractor {
    func exctract(from mainWorld: World, to renderWorld: World) async {
        renderWorld.clear()
        renderWorld.insertResource(MainWorld(world: mainWorld))
        await renderWorld.runScheduler(.extract)
    }
}

/// The resource that contains the main world.
struct MainWorld: Resource {
    var world: World
}

/// A property wrapper that allows you to extract a resource from the main world.
@propertyWrapper
public final class Extract<T: SystemQuery>: @unchecked Sendable {
    private var _value: T!
    public var wrappedValue: T {
        self._value
    }

    /// Initialize a new extract.
    public init() { }

    /// Initialize a new extract.
    /// - Parameter from: The world to extract the resource from.
    public init(from world: World) {
        self._value = T.init(from: world)
    }

    /// Call the extract.
    /// - Returns: The extracted resource.
    public func callAsFunction() -> T {
        self._value
    }
}

extension Extract: SystemQuery {
    public func update(from world: consuming World) {
        let world = world
        if _value == nil {
            _value = T.init(from: world)
        }
        if let resource = world.getResource(MainWorld.self) {
            _value?.update(from: resource.world)
        }
    }
}

public extension SchedulerName {
    /// The render scheduler.
    static let render = SchedulerName(rawValue: "RenderWorld_Render")
    static let extract = SchedulerName(rawValue: "RenderWorld_Extract")

    static let beginRender = SchedulerName(rawValue: "RenderWorld_BeginFrame")
    static let endRender = SchedulerName(rawValue: "RenderWorld_EndFrame")
}

public extension AppWorldName {
    /// The render world that will render the scene.
    static let renderWorld = AppWorldName(rawValue: "RenderWorld")
}
