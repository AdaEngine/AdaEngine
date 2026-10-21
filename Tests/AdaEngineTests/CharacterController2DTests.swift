import AdaECS
@testable import AdaPhysics
import AdaTransform
import AdaUtils
import Foundation
import Math
import Testing

@MainActor
@Suite(.serialized)
struct CharacterController2DTests {
    private func level(floor: Bool = true) async throws -> PhysicsJoint2DFixture {
        let fixture = try await PhysicsJoint2DFixture(gravity: [0, -10])
        if floor { fixture.app.main.spawn { Collision2DComponent(shapes: [.generateBox(width: 100, height: 1)]); Transform(position: [0, -0.5, 0]) } }
        await fixture.app.main.runScheduler(.physicsSync)
        return fixture
    }
    private func move(_ fixture: PhysicsJoint2DFixture, _ controller: inout CharacterController2DComponent, _ position: inout Vector2, steps: Int, dt: Float = 1.0 / 60) throws {
        let world = try #require(fixture.app.main.physicsWorld2D)
        for _ in 0..<steps { try world.moveCharacter(&controller, position: &position, deltaTime: dt) }
    }

    @Test
    func flatMotionAccelerationBrakingAndFrameRatesAgree() async throws {
        let fixture = try await level()
        var positions: [Float] = []
        for rate in [30, 60, 120] {
            var character = CharacterController2DComponent()
            character.desiredVelocity = [3, 100]
            var position: Vector2 = [0, 2]
            try move(fixture, &character, &position, steps: rate * 2, dt: 1 / Float(rate))
            #expect(character.isGrounded && abs(position.y) < 0.03)
            #expect(abs(character.velocity.x - 3) < 0.02)
            positions.append(position.x)
            character.desiredVelocity = .zero
            try move(fixture, &character, &position, steps: rate / 2, dt: 1 / Float(rate))
            #expect(abs(character.velocity.x) < 0.01)
        }
        #expect(try #require(positions.max()) - #require(positions.min()) < 0.06)
    }

    @Test
    func jumpHitsCeilingAndLandsWhileAirRequestsAreConsumed() async throws {
        let fixture = try await level()
        fixture.app.main.spawn { Collision2DComponent(shapes: [.generateBox(width: 10, height: 0.2)]); Transform(position: [0, 2.4, 0]) }
        await fixture.app.main.runScheduler(.physicsSync)
        var character = CharacterController2DComponent()
        var position: Vector2 = [0, 1]
        try move(fixture, &character, &position, steps: 60)
        #expect(character.isGrounded)
        character.jumpRequested = true
        var peak: Float = 0
        var airborne = false
        for _ in 0..<120 {
            try move(fixture, &character, &position, steps: 1)
            peak = max(peak, position.y)
            airborne = airborne || !character.isGrounded
        }
        #expect(airborne && peak > 0.2 && peak < 0.55)
        #expect(character.isGrounded && !character.jumpRequested && abs(position.y) < 0.03)
    }

    @Test
    func sweepsIgnoreSensorsAndMasksAndStopAtThinWalls() async throws {
        let fixture = try await level()
        for (x, sensor, category) in [(Float(2), true, UInt64(1)), (4, false, 2), (6, false, 1)] {
            fixture.app.main.spawn {
                Collision2DComponent(
                    shapes: [.generateBox(width: 0.01, height: 5)],
                    mode: sensor ? .trigger : .default,
                    filter: .init(categoryBitMask: CollisionGroup(rawValue: category))
                )
                Transform(position: [x, 2, 0])
            }
        }
        await fixture.app.main.runScheduler(.physicsSync)
        var character = CharacterController2DComponent()
        character.filter.collisionBitMask = .default
        character.settings.acceleration = 100000
        character.desiredVelocity = [1000, 0]
        var position: Vector2 = [0, 0.02]
        try move(fixture, &character, &position, steps: 4)
        #expect(position.x > 5.5 && position.x < 5.7)
        #expect(character.isGrounded && abs(position.y) < 0.03)
    }

    @Test
    func walkableSlopeClimbsAndSteepSlopeDoesNot() async throws {
        for slope in [Float(0.5), 2] {
            let fixture = try await level(floor: false)
            let shape = try Shape2DResource.generateSegment(from: [-4, -4 * slope], to: [4, 4 * slope])
            fixture.app.main.spawn { Collision2DComponent(shapes: [shape]); Transform() }
            await fixture.app.main.runScheduler(.physicsSync)
            var character = CharacterController2DComponent()
            var position: Vector2 = [-2, -2 * slope + 0.6]
            try move(fixture, &character, &position, steps: 60)
            let start = position.y
            character.desiredVelocity = [1.5, 0]
            try move(fixture, &character, &position, steps: 120)
            if slope < 1 { #expect(character.isGrounded && position.y > start + 0.8) } else { #expect(!character.isGrounded && position.y < start + 0.2) }
        }
    }

    @Test
    func groundSnapFollowsSmallDescendingStepAndTeleportResetsMotion() async throws {
        let fixture = try await level(floor: false)
        fixture.app.main.spawn { Collision2DComponent(shapes: [.generateBox(width: 10, height: 1)]); Transform(position: [-5, -0.5, 0]) }
        fixture.app.main.spawn { Collision2DComponent(shapes: [.generateBox(width: 10, height: 1)]); Transform(position: [5, -0.6, 0]) }
        await fixture.app.main.runScheduler(.physicsSync)
        var character = CharacterController2DComponent()
        var position: Vector2 = [-1, 1]
        try move(fixture, &character, &position, steps: 60)
        character.desiredVelocity = [2, 0]
        try move(fixture, &character, &position, steps: 90)
        #expect(character.isGrounded && position.x > 1 && abs(position.y + 0.1) < 0.03)
        position = [20, 5]
        character.desiredVelocity = .zero
        try move(fixture, &character, &position, steps: 1)
        #expect(abs(position.x - 20) < 0.001 && abs(character.velocity.x) < 0.001 && !character.isGrounded)
    }

    @Test
    func oneSidedChainAllowsJumpFromBelowAndLandingAbove() async throws {
        let fixture = try await level(floor: false)
        fixture.app.main.spawn { Collision2DComponent(shapes: [.generateBox(width: 20, height: 1)]); Transform(position: [0, -3.5, 0]) }
        let chain = try Shape2DResource.generateChain(points: [[3, 0], [-3, 0]])
        fixture.app.main.spawn { Collision2DComponent(shapes: [chain]); Transform() }
        await fixture.app.main.runScheduler(.physicsSync)
        var character = CharacterController2DComponent()
        character.settings.jumpSpeed = 8
        var position: Vector2 = [0, -2.5]
        try move(fixture, &character, &position, steps: 60)
        character.jumpRequested = true
        var peak: Float = -3
        for _ in 0..<120 { try move(fixture, &character, &position, steps: 1); peak = max(peak, position.y) }
        #expect(peak > 0.05)
        #expect(character.isGrounded && abs(position.y) < 0.03)
    }

    @Test
    func supportPointUsesTranslatedRotatedRoundedGeometry() async throws {
        let fixture = try await level(floor: false)
        let shape = try Shape2DResource.generateRoundedBox(width: 10, height: 1, radius: 0.1)
        let ground = fixture.app.main.spawn { Collision2DComponent(shapes: [shape]); Transform(rotation: Quat(axis: [0, 0, 1], angle: 0.2), position: [8, -2, 0]) }
        await fixture.app.main.runScheduler(.physicsSync)
        var character = CharacterController2DComponent()
        var position: Vector2 = [8, 0]
        try move(fixture, &character, &position, steps: 120)
        #expect(character.isGrounded && character.groundEntityID == ground.id)
        let point = try #require(character.groundPoint)
        let relative = point - Vector2(8, -2)
        let localY = -Math.sin(0.2) * relative.x + Math.cos(0.2) * relative.y
        #expect(abs(localY - 0.5) < 0.02)
    }

    @Test
    func ECSMovesCharactersAndReportsConflictingBodies() async throws {
        let fixture = try await level()
        fixture.app.main.insertResource(FixedTime(deltaTime: 1.0 / 60))
        let entity = fixture.app.main.spawn { CharacterController2DComponent(); Transform(position: [0, 2, 0]) }
        for _ in 0..<90 {
            await fixture.app.main.runScheduler(.physicsSync)
            await fixture.app.main.runScheduler(.physicsStep)
            await fixture.app.main.runScheduler(.physicsWriteback)
        }
        #expect(entity.components[CharacterController2DComponent.self]?.isGrounded == true)
        entity.components[PhysicsBody2DComponent.self] = PhysicsBody2DComponent(shapes: [.generateCircle(radius: 1)], mass: 1)
        await fixture.app.main.runScheduler(.physicsSync)
        await fixture.app.main.runScheduler(.physicsWriteback)
        #expect(entity.components[CharacterController2DComponent.self]?.lastError == .conflictingBody)
        #expect(entity.components[CharacterController2DComponent.self]?.groundPoint == nil)
    }

    @Test
    func codingCopyingAndInvalidInputDoNotLeakRuntimeState() async throws {
        let fixture = try await level()
        let world = try #require(fixture.app.main.physicsWorld2D)
        var character = CharacterController2DComponent()
        var position: Vector2 = [0, 1]
        try move(fixture, &character, &position, steps: 60)
        let decoded = try JSONDecoder().decode(CharacterController2DComponent.self, from: JSONEncoder().encode(character))
        #expect(decoded.runtime == nil && !decoded.isGrounded && decoded.velocity == .zero)
        character.desiredVelocity = [3, 0]
        try move(fixture, &character, &position, steps: 10)
        var copy = character
        var copyPosition = position
        copy.desiredVelocity = .zero
        try move(fixture, &copy, &copyPosition, steps: 30)
        try move(fixture, &character, &position, steps: 1)
        #expect(character.velocity.x > 2 && abs(copy.velocity.x) < 0.01)
        #expect(throws: CharacterController2DError.invalidMotion) { try world.moveCharacter(&character, position: &position, deltaTime: 0) }
        character.settings.radius = 0
        #expect(throws: CharacterController2DError.invalidConfiguration) { try world.moveCharacter(&character, position: &position, deltaTime: 1.0 / 60) }
    }
}
