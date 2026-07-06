//
//  Physics3DTests.swift
//  AdaEngine
//
//  Created by Codex on 7/6/26.
//

import AdaECS
@_spi(Internal) @testable import AdaApp
@testable import AdaPhysics
import AdaTransform
import Testing

@MainActor
struct Physics3DTests {

    let world: AppWorlds

    init() async throws {
        let world = AppWorlds(main: World())
        self.world = world

        world
            .addPlugin(MainSchedulerPlugin())
            .addPlugin(Physics3DPlugin())
            .addPlugin(TransformPlugin())
        try await world.build()
    }

    @Test
    func dynamicBodyFallsUnderGravity() async throws {
        let box = world.main.spawn {
            PhysicsBody3DComponent(
                shapes: [Shape3DResource.generateBox(width: 1, height: 1, depth: 1)],
                mass: 1,
                mode: .dynamic
            )
            Transform(position: [0, 4, 0])
        }

        try await world.update()

        let runtimeBody = try #require(box.components[PhysicsBody3DComponent.self]?.runtimeBody)
        let startY = try #require(box.components[Transform.self]?.position.y)
        let physicsWorld = try #require(world.main.physicsWorld3D)

        for _ in 0..<60 {
            physicsWorld.updateSimulation(1.0 / 60.0)
        }
        await world.main.runScheduler(.postUpdate)

        let endY = try #require(box.components[Transform.self]?.position.y)

        #expect(runtimeBody.getPosition().y < startY)
        #expect(endY < startY)
    }
}
