import AdaApp
import AdaECS
import AdaScripting
import AdaTransform
import Foundation
import Math
import Testing

@Suite("Annotation-driven Gravity demo", .serialized)
struct Gravity2DDemoScriptTests {
    @Test("Runs the Gravity 2D demo script with multiple batches")
    @MainActor
    func runsGravity2DDemoScript() async throws {
        Transform.registerComponent()
        GravityVelocity.registerComponent()
        GravityPulse.registerComponent()

        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let scriptURL = repositoryURL
            .appendingPathComponent("Demos/Resources/Gravity/gravity_swarm.gravity")
        let plugin = try GravityScriptPlugin(contentsOf: scriptURL)
        let world = World(name: "Gravity 2D Demo Script Test")
        let movingEntity = world.spawn {
            Transform(position: Vector3(0, 0, 0))
            GravityVelocity(
                velocity: Vector2(10, 0),
                boundsMin: Vector2(-10, -10),
                boundsMax: Vector2(10, 10)
            )
            GravityPulse(phase: 0.25, speed: 0.5, minimumScale: 0.5, maximumScale: 1.5)
        }
        let bouncingEntity = world.spawn {
            Transform(position: Vector3(9.9, 0, 0))
            GravityVelocity(
                velocity: Vector2(5, 0),
                boundsMin: Vector2(-10, -10),
                boundsMax: Vector2(10, 10)
            )
            GravityPulse(phase: 0.9, speed: 0.3, minimumScale: 0.5, maximumScale: 1.5)
        }

        plugin.setup(in: AppWorlds(main: world))
        await world.runScheduler(.update)

        let movingTransform = try #require(world.get(Transform.self, from: movingEntity.id))
        let bouncingTransform = try #require(world.get(Transform.self, from: bouncingEntity.id))
        let bouncingVelocity = try #require(world.get(GravityVelocity.self, from: bouncingEntity.id))
        #expect(abs(movingTransform.position.x - 0.5) < 0.0001)
        #expect(abs(movingTransform.scale.x - 1.05) < 0.0001)
        #expect(abs(movingTransform.scale.y - 1.05) < 0.0001)
        #expect(bouncingTransform.position == Vector3(10, 0, 0))
        #expect(abs(bouncingTransform.scale.x - 0.67) < 0.0001)
        #expect(abs(bouncingTransform.scale.y - 0.67) < 0.0001)
        #expect(bouncingVelocity.velocity == Vector2(-5, 0))
        #expect(plugin.diagnostics.isEmpty)
    }
}

@Component
private struct GravityVelocity: Codable, Sendable {
    var velocity: Vector2
    var boundsMin: Vector2
    var boundsMax: Vector2
}

@Component
private struct GravityPulse: Codable, Sendable {
    var phase: Float
    var speed: Float
    var minimumScale: Float
    var maximumScale: Float
}
