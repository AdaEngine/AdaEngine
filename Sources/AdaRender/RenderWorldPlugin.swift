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

        let renderWorld = app.createSubworld(by: .renderWorld)
        renderWorld.insertResource(RenderGraph(label: "RenderWorld_Root"))
        renderWorld.setExctractor(RenderWorldExctractor())
        renderWorld.mainWorld.setSchedulers([
            .update,
            .render
        ])
        renderWorld.insertResource(
            DefaultSchedulerOrder(
                order: [.update, .render]
            )
        )

        renderWorld.mainWorld
            .addSystem(RenderWorldSystem.self, on: .render)
    }
}

/// The system that renders the world.
@System
struct RenderWorldSystem {

    private let renderGraphExecutor = RenderGraphExecutor()

    init(world: World) { }

    @ResQuery
    private var renderGraph: RenderGraph!

    func update(context: inout UpdateContext) {
        let world = context.world
        context.taskGroup.addTask {
            do {
                try await self.renderGraphExecutor.execute(renderGraph, in: world)
            } catch {
                print(error)
            }
        }
    }
}

/// The extractor that extracts the main world to the render world.
struct RenderWorldExctractor: WorldExctractor {
    func exctract(from mainWorld: World, to renderWorld: World) {
        renderWorld.clear()
        renderWorld.insertResource(MainWorld(world: mainWorld))
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
}

public extension AppWorldName {
    /// The render world that will render the scene.
    static let renderWorld = AppWorldName(rawValue: "RenderWorld")
}
