import AdaECS
@testable import AdaPhysics
import AdaTransform
import AdaUtils
import box2d
import Foundation
import Math
import Testing

@MainActor
@Suite(.serialized)
struct DynamicCharacterController2DTests {
    private func level() async throws -> PhysicsJoint2DFixture {
        let fixture = try await PhysicsJoint2DFixture(gravity: [0, -10])
        fixture.app.main.insertResource(FixedTime(deltaTime: 1.0 / 60))
        fixture.app.main.spawn { Collision2DComponent(shapes: [.generateBox(width: 100, height: 1)]); Transform(position: [0, -0.5, 0]) }
        return fixture
    }
    private func player(_ fixture: PhysicsJoint2DFixture, at position: Vector2 = [0, 2]) -> Entity {
        var controller = CharacterController2DComponent()
        controller.mode = .dynamic
        return fixture.app.main.spawn { controller; Transform(position: [position.x, position.y, 0]) }
    }
    private func step(_ fixture: PhysicsJoint2DFixture, count: Int = 1) async {
        for _ in 0..<count {
            await fixture.app.main.runScheduler(.physicsSync)
            await fixture.app.main.runScheduler(.physicsStep)
            await fixture.app.main.runScheduler(.physicsWriteback)
        }
    }

    @Test
    func nativeGravityRunsOnceAndJumpLands() async throws {
        let fixture = try await level()
        let character = player(fixture, at: [0, 10])
        let free = fixture.body(at: [4, 10])
        await step(fixture, count: 60)
        let y = try #require(character.components[Transform.self]).position.y
        let freeY = try #require(free.components[PhysicsBody2DComponent.self]?.runtimeBody).getPosition().y
        #expect(abs(y - freeY) < 0.01 && y > 4.8 && y < 5.1)
        await step(fixture, count: 90)
        #expect(character.components[CharacterController2DComponent.self]?.isGrounded == true)
        character.components[CharacterController2DComponent.self]?.jumpRequested = true
        var peak: Float = 0
        var airborne = false
        for _ in 0..<120 {
            await step(fixture)
            peak = max(peak, character.components[Transform.self]?.position.y ?? 0)
            airborne = airborne || character.components[CharacterController2DComponent.self]?.isGrounded == false
        }
        #expect(airborne && peak > 0.9 && peak < 1.5)
        #expect(character.components[CharacterController2DComponent.self]?.isGrounded == true)
    }

    @Test
    func lightBodyMovesAndHeavyBodyRespectsDriveBound() async throws {
        var distances: [Float] = []
        for mass in [Float(0.1), 100] {
            let fixture = try await level()
            let character = player(fixture, at: [-2, 1])
            let object = fixture.app.main.spawn {
                PhysicsBody2DComponent(shapes: [.generateBox(width: 0.8, height: 0.8)], massProperties: .init(mass: mass, inertia: [0, 0, mass]))
                Transform(position: [0, 0.4, 0])
            }
            await step(fixture, count: 60)
            character.components[CharacterController2DComponent.self]?.dynamics.maximumDriveForce = 20
            character.components[CharacterController2DComponent.self]?.desiredVelocity = [3, 0]
            await step(fixture, count: 120)
            distances.append(try #require(object.components[PhysicsBody2DComponent.self]?.runtimeBody).getPosition().x)
            let runtime = try #require(character.components[CharacterController2DComponent.self]?.runtime)
            #expect(abs(b2Joint_GetConstraintForce(runtime.mover).x) <= 20.01)
        }
        #expect(distances[0] > 1 && abs(distances[1]) < 0.2)
    }

    @Test
    func movingPlatformCarriesCharacterAndSupportPointStaysOnIt() async throws {
        let fixture = try await level()
        let platform = fixture.app.main.spawn {
            PhysicsBody2DComponent(shapes: [.generateBox(width: 8, height: 0.5)], mass: 1, mode: .kinematic)
            Transform(position: [0, 1, 0])
        }
        let character = player(fixture, at: [0, 3])
        await step(fixture, count: 90)
        #expect(character.components[CharacterController2DComponent.self]?.groundEntityID == platform.id)
        let start = try #require(character.components[Transform.self]).position.x
        platform.components[PhysicsBody2DComponent.self]?.linearVelocity = [1, 0.25]
        await step(fixture, count: 120)
        let controller = try #require(character.components[CharacterController2DComponent.self])
        #expect(controller.isGrounded && controller.groundEntityID == platform.id)
        #expect(abs(try #require(character.components[Transform.self]).position.x - start - 2) < 0.15)
        let point = try #require(controller.groundPoint)
        let platformPosition = try #require(platform.components[PhysicsBody2DComponent.self]?.runtimeBody).getPosition()
        #expect(abs(point.y - platformPosition.y - 0.25) < 0.03)
    }

    @Test
    func filtersIgnoreSensorPlatformsAndExcludedLayers() async throws {
        let fixture = try await level()
        fixture.app.main.spawn { Collision2DComponent(shapes: [.generateBox(width: 10, height: 0.2)], mode: .trigger); Transform(position: [0, 1.5, 0]) }
        fixture.app.main.spawn {
            Collision2DComponent(shapes: [.generateBox(width: 10, height: 0.2)], filter: .init(categoryBitMask: CollisionGroup(rawValue: 2)))
            Transform(position: [0, 0.9, 0])
        }
        let character = player(fixture, at: [0, 3])
        character.components[CharacterController2DComponent.self]?.filter.collisionBitMask = .default
        await step(fixture, count: 120)
        #expect(abs(try #require(character.components[Transform.self]).position.y) < 0.06)
        #expect(character.components[CharacterController2DComponent.self]?.isGrounded == true)
    }

    @Test
    func modeSwitchTeleportRemovalAndRetainedCopiesReleaseNativeState() async throws {
        let fixture = try await level()
        let character = player(fixture)
        await step(fixture, count: 90)
        let runtime = try #require(character.components[CharacterController2DComponent.self]?.runtime)
        let retainedBody = try #require(runtime.body)
        let bodyID = retainedBody.bodyId
        let anchorID = runtime.airAnchor
        let native = try #require(fixture.app.main.physicsWorld2D)
        character.components[Transform.self]?.position = [10, 5, 0]
        character.components[CharacterController2DComponent.self]?.desiredVelocity = .zero
        await step(fixture)
        #expect(abs(try #require(character.components[Transform.self]).position.x - 10) < 0.01)
        character.components[CharacterController2DComponent.self]?.mode = .query
        await step(fixture)
        #expect(!b2Body_IsValid(bodyID) && !b2Body_IsValid(anchorID))
        #expect(b2World_GetCounters(native.worldId).bodyCount == 1 && b2World_GetCounters(native.worldId).jointCount == 0)
        character.components[CharacterController2DComponent.self]?.mode = .dynamic
        await step(fixture)
        let replacement = try #require(character.components[CharacterController2DComponent.self]?.runtime?.body).bodyId
        fixture.app.main.removeEntity(character)
        await fixture.app.main.runScheduler(.physicsSync)
        #expect(!b2Body_IsValid(replacement) && native.characterRecords.isEmpty)
    }

    @Test
    func disposedWorldsAndInvalidDynamicsReleaseOwnedBodies() async throws {
        weak var physics: PhysicsWorld2D?
        var retained: CharacterController2DComponent?
        do {
            let fixture = try await level()
            await fixture.app.main.runScheduler(.startup)
            let character = player(fixture)
            await step(fixture)
            let id = try #require(character.components[CharacterController2DComponent.self]?.runtime?.body).bodyId
            character.components[CharacterController2DComponent.self]?.dynamics.mass = 0
            await fixture.app.main.runScheduler(.physicsSync)
            #expect(!b2Body_IsValid(id))
            #expect(character.components[CharacterController2DComponent.self]?.lastError == .invalidConfiguration)
            character.components[CharacterController2DComponent.self]?.dynamics.mass = 1
            character.components[Transform.self]?.position.x = .nan
            await fixture.app.main.runScheduler(.physicsSync)
            #expect(character.components[CharacterController2DComponent.self]?.lastError == .invalidMotion)
            character.components[Transform.self]?.position = [0, 2, 0]
            await step(fixture)
            retained = character.components[CharacterController2DComponent.self]
            physics = fixture.app.main.physicsWorld2D
        }
        #expect(physics == nil && retained?.runtime?.world == nil)
    }

    @Test
    func physicalCapsuleIgnoresVisualScaleAndRotation() async throws {
        let fixture = try await level()
        let character = player(fixture)
        character.components[Transform.self]?.scale = [2, 3, 1]
        character.components[Transform.self]?.rotation = Quat(axis: [0, 0, 1], angle: 0.4)
        await step(fixture)
        let transform = try #require(character.components[Transform.self])
        let world = try #require(fixture.app.main.physicsWorld2D)
        let hit = try #require(world.raycast(from: [-2, transform.position.y + 0.9], to: [2, transform.position.y + 0.9]).first)
        #expect(hit.entity === character && abs(hit.point.x + 0.35) < 0.01)
        #expect(abs(transform.rotation.angle2D.radians - 0.4) < 0.001)
    }

    @Test
    func dynamicSlopeDriveHonorsWalkableNormals() async throws {
        for slope in [Float(0.3), 2] {
            let fixture = try await level()
            let ramp = try Shape2DResource.generateSegment(from: [0, 0], to: [6, 6 * slope])
            fixture.app.main.spawn { Collision2DComponent(shapes: [ramp]); Transform() }
            let character = player(fixture, at: [-1, 1])
            await step(fixture, count: 60)
            character.components[CharacterController2DComponent.self]?.desiredVelocity = [2, 0]
            await step(fixture, count: 120)
            let position = try #require(character.components[Transform.self]).position
            if slope < 1 { #expect(position.y > 0.4) } else { #expect(position.y < 0.4 && position.x < 0.5) }
        }
    }

    @Test
    func jointsCanAttachToDynamicCharactersAndCodecKeepsMode() async throws {
        let fixture = try await level()
        let character = player(fixture, at: [0, 3])
        let anchor = fixture.body(at: [0, 5], mode: .static)
        let owner = try await fixture.connect(.distance(entityA: anchor, entityB: character, settings: .init(length: 2)))
        await step(fixture, count: 30)
        #expect(owner.components[PhysicsJoint2DComponent.self]?.isConnected == true)
        let component = try #require(character.components[CharacterController2DComponent.self])
        let decoded = try JSONDecoder().decode(CharacterController2DComponent.self, from: JSONEncoder().encode(component))
        #expect(decoded.mode == .dynamic && decoded.runtime == nil && !decoded.isGrounded)
        var manual = decoded
        var position: Vector2 = .zero
        #expect(throws: CharacterController2DError.dynamicRequiresECS) { try fixture.app.main.physicsWorld2D?.moveCharacter(&manual, position: &position, deltaTime: 1.0 / 60) }
    }
}
