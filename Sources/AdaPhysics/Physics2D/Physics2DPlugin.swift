//
//  Physics2DPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/11/22.
//

import AdaApp
import AdaECS
import AdaRender
import AdaUtils
import Math

/// Setup 2D physics to the scene.
public struct Physics2DPlugin: Plugin {

    public let gravity: Vector2

    public init(gravity: Vector2 = [0, -9.81]) {
        self.gravity = gravity
    }

    public func setup(in app: AppWorlds) {
        PhysicsBody2DComponent.registerComponent()
        PhysicsJoint2DComponent.registerComponent()
        Collision2DComponent.registerComponent()
        
        app
            .insertResource(
                Physics2DWorldComponent(
                    world: PhysicsWorld2D(gravity: gravity)
                )
            )
            .addSystem(Physics2DSystem.self, on: .fixedUpdate)
            .addSystem(PhysicsEventProxySystem.self, on: .startup)

        guard let renderWorld = app.getSubworldBuilder(by: .renderWorld) else {
            return
        }
        renderWorld
            .addSystem(Physics2DDebugDrawSystem.self, on: .render)
            .addSystem(DebugPhysicsExctract2DSystem.self, on: .extract)
    }
}

/// Resource contains ``PhysicsWorld2D``.
public struct Physics2DWorldComponent: Resource {
    public let world: PhysicsWorld2D
}

public extension World {
    /// Returns ``PhysicsWorld2D`` instance is ``Physics2DPlugin`` is connected to the scene.
    /// - Note: ``Physics2DPlugin`` connected by default on first update tick in current scene.
    @MainActor
    var physicsWorld2D: PhysicsWorld2D? {
        return self.getResource(Physics2DWorldComponent.self)?.world
    }
}

@System
func PhysicsEventProxy(
    _ collisionBeganSender: EventsSender<CollisionEvents.Began>,
    _ collisionEndSender: EventsSender<CollisionEvents.Ended>,
    _ eventDisposeBag: Local<Set<AnyCancellable>> = .init([])
) {
    EventManager.default.subscribe(to: CollisionEvents.Began.self) { event in
        collisionBeganSender(event)
    }
    .store(in: &eventDisposeBag.wrappedValue)

    EventManager.default.subscribe(to: CollisionEvents.Ended.self) { event in
        collisionEndSender(event)
    }
    .store(in: &eventDisposeBag.wrappedValue)
}
