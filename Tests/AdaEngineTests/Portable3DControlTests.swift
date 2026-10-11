import AdaAnimation
@_spi(Internal) @testable import AdaApp
import AdaECS
@testable import AdaPhysics
import AdaScene
import AdaScripting
import AdaTransform
import AdaUtils
import Foundation
import Math
import Testing

@MainActor
@Suite(.serialized)
struct Portable3DControlTests {
    @Test func scriptsReadGroundedStateAndRequestJumpAndTeleportReset() async throws {
        CharacterController3DComponent.registerComponent()
        let world = World()
        let entity = world.spawn { CharacterController3DComponent() }
        let script = try AdaScriptPlugin(source: """
        @system(id: "controller-controls")
        class ControllerControls {
            @query(CharacterController3DComponent) var characters;
            func update(context) {
                for (var row in characters) {
                    row.characterController3DComponent.jumpRequested = !row.characterController3DComponent.isGrounded;
                    row.characterController3DComponent.resetMotion = true;
                }
            }
        }
        """, name: "ControllerControls")
        script.setup(in: AppWorlds(main: world))
        await world.runScheduler(.update)
        let controller = try #require(entity.components[CharacterController3DComponent.self])
        #expect(controller.jumpRequested && controller.resetMotion)
        #expect(script.diagnostics.isEmpty)
    }

    @Test func playbackPreservesCycleAndKeepsInstancesIndependent() async throws {
        let pose = SkeletalJointPose()
        let rig = try SkeletalRig(nodes: [.init(parentIndex: nil, restPose: pose, restMatrix: pose.matrix)])
        func clip(_ name: String, duration: Double) throws -> SkeletalAnimationClip {
            .init(name: name, tracks: [try SkeletalAnimationTrack(nodeIndex: 0, path: .translation,
                interpolation: .linear, times: [0, duration], values: [.zero, [1, 0, 0, 0]])])
        }
        var player = try SkeletalAnimationPlayer(rig: rig, clips: [clip("Slow", duration: 2), clip("Fast", duration: 1)])
        try player.play("Slow", transitionDuration: 0)
        player.seek(to: 0.5)
        let world = World()
        let app = AppWorlds(main: world)
        app.addPlugin(MainSchedulerPlugin()).addPlugin(TransformPlugin()).addPlugin(Model3DPlugin())
        try await app.build()
        let first = world.spawn { ModelAnimation3DComponent(player: player) }
        let second = world.spawn { ModelAnimation3DComponent(player: player) }
        var control = ModelAnimationPlayback3DComponent()
        control.clip = "Fast"
        control.synchronizePhase = true
        control.speed = 1.5
        let owner = world.spawn {
            control
            Model3DSourceState(reference: Model3DSource(), rootEntityID: first.id)
        }
        await world.runScheduler(.postUpdate, deltaTime: 0)
        let played = try #require(first.components[ModelAnimation3DComponent.self]?.player)
        #expect(played.time == 0.25)
        #expect(played.clips[played.clipIndex ?? 0].name == "Fast")
        #expect(played.speed == 1.5)
        #expect(second.components[ModelAnimation3DComponent.self]?.player.time == 0.5)
        control.clip = "Missing"
        owner.components[ModelAnimationPlayback3DComponent.self] = control
        await world.runScheduler(.postUpdate, deltaTime: 0)
        #expect(first.components[ModelAnimation3DComponent.self]?.player.time == 0.25)
        control.clip = "Slow"
        control.repeats = false
        control.isPlaying = false
        owner.components[ModelAnimationPlayback3DComponent.self] = control
        await world.runScheduler(.postUpdate, deltaTime: 0)
        #expect(first.components[ModelAnimation3DComponent.self]?.player.time == 0)
        #expect(first.components[ModelAnimation3DComponent.self]?.player.isPlaying == false)
        #expect(first.components[ModelAnimation3DComponent.self]?.player.repeats == false)
    }

    @Test func cameraRetractsAtAnObstacleAndRecoversSmoothly() async throws {
        let app = AppWorlds(main: World())
        app.addPlugin(MainSchedulerPlugin()).addPlugin(Physics3DPlugin()).addPlugin(TransformPlugin())
        try await app.build()
        let wall = app.main.spawn {
            PhysicsBody3DComponent(shapes: [.generateBox(width: 6, height: 6, depth: 0.2)], mode: .static)
            Transform(position: [0, 1, -2])
        }
        var collision = CameraCollision3DComponent()
        collision.origin = [0, 1, 0]
        collision.target = collision.origin
        collision.destination = [0, 1, -6]
        let camera = app.main.spawn { collision; Transform() }
        await app.main.runScheduler(.physicsSync)
        await app.main.runScheduler(.postUpdate, deltaTime: 1 / 60)
        let stopped = try #require(camera.components[CameraCollision3DComponent.self])
        #expect(stopped.isOccluded)
        #expect(stopped.actualDistance < 1.8)
        #expect(stopped.actualDistance > 1.5)
        #expect(try #require(camera.components[Transform.self]).position.z > -1.8)
        app.main.removeEntity(wall.id)
        await app.main.runScheduler(.physicsSync)
        await app.main.runScheduler(.postUpdate, deltaTime: 1 / 60)
        let recovering = try #require(camera.components[CameraCollision3DComponent.self])
        #expect(!recovering.isOccluded)
        #expect(recovering.actualDistance > stopped.actualDistance)
        #expect(recovering.actualDistance < 5.92)
    }

    @Test func controllerSerializationKeepsConfigurationAndDiscardsTransientMotion() throws {
        var controller = CharacterController3DComponent(radius: 0.4, height: 2.15)
        controller.desiredVelocity = [3, 0, 0]
        controller.jumpRequested = true
        controller.resetMotion = true
        controller.velocity = [2, 5, 0]
        controller.jumpSpeed = 7
        let decoded = try JSONDecoder().decode(CharacterController3DComponent.self, from: JSONEncoder().encode(controller))
        #expect(decoded.height == 2.15)
        #expect(decoded.jumpSpeed == 7)
        #expect(decoded.desiredVelocity == .zero)
        #expect(decoded.velocity == .zero)
        #expect(!decoded.jumpRequested && !decoded.resetMotion && !decoded.isGrounded)
    }
}
