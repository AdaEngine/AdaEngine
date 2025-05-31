//
//  WorldPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/11/22.
//

import AdaApp
import AdaECS
import AdaUtils

public struct RenderWorldPlugin: Plugin {

    public init() {}

    public func setup(in app: AppWorlds) {
        VisibleEntities.registerComponent()
        Visibility.registerComponent()
        NoFrustumCulling.registerComponent()
        BoundingComponent.registerComponent()

        let renderWorld = app.createSubworld(by: .renderWorld)
        renderWorld.insertResource(RenderGraph(label: "RenderWorld_Root"))
        renderWorld.setExctractor(RenderWorldExctractor())
        renderWorld.mainWorld.setSchedulers([
            .update,
            .render
        ])

        renderWorld.mainWorld
            .addSystem(RenderWorldSystem.self, on: .render)
    }
}

@System
struct RenderWorldSystem {

    private let renderGraphExecutor = RenderGraphExecutor()

    init(world: World) { }

    @ResourceQuery
    private var renderGraph: RenderGraph!

    func update(context: UpdateContext) {
        context.taskGroup.addTask {
            do {
                try await self.renderGraphExecutor.execute(renderGraph, in: context.world)
            } catch {
                print(error)
            }
        }
    }
}

struct RenderWorldExctractor: WorldExctractor {
    func exctract(from mainWorld: World, to renderWorld: World) {
        renderWorld.clear()
        renderWorld.insertResource(MainWorld(world: mainWorld))
    }
}

struct MainWorld: Resource {
    var world: World
}

/// A property wrapper that allows you to query a resource in a system.
@propertyWrapper
public final class Extract<T: SystemQuery>: @unchecked Sendable {
    private var _value: T!
    public var wrappedValue: T {
        self._value
    }

    public init() { }

    public init(from world: World) {
        self._value = T.init(from: world)
    }
}

extension Extract: SystemQuery {
    public func update(from world: World) {
        if _value == nil {
            _value = T.init(from: world)
        }
        if let resource = world.getResource(MainWorld.self) {
            _value?.update(from: resource.world)
        }
    }
}

public extension Scheduler {
    static let render = Scheduler(rawValue: "RenderWorld_Render")
}

public extension AppWorldName {
    static let renderWorld = AppWorldName(rawValue: "RenderWorld")
}
